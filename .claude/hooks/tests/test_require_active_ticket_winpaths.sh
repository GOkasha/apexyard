#!/bin/bash
# Tests for the Windows path-normalization fix (GOkasha/apexyard#11) in
# require-active-ticket.sh, _lib-normalize-path.sh, and the rm multi-target
# extraction added to _lib-detect-bash-write.sh.
#
# Windows is simulated cross-platform: a real (forward-slash) sandbox path
# is converted to backslashes with `winify`, fed to the hook as the tool's
# file_path / bash command, and the hook is expected to normalize it back.
#
# Coverage:
#   - normalize_path: backslash->slash, POSIX no-op, idempotent, empty
#   - backslash `.claude/session` marker write is exempt
#   - backslash workspace source edit resolves the per-project marker
#       (allowed with marker, blocked without)
#   - rm of a `.claude/session` marker (fwd + backslash) allowed
#   - rm -rf of `.claude/session/` allowed
#   - rm mixing an exempt and a non-exempt target blocked
#   - rm of a non-exempt target blocked
#   - POSIX forward-slash behaviour unchanged (regression)
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/require-active-ticket.sh"
LIB_BASH="$SRC_ROOT/.claude/hooks/_lib-detect-bash-write.sh"
LIB_CFG="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"
LIB_NORM="$SRC_ROOT/.claude/hooks/_lib-normalize-path.sh"
DEFAULTS="$SRC_ROOT/.claude/project-config.defaults.json"

for f in "$HOOK_SRC" "$LIB_BASH" "$LIB_CFG" "$LIB_NORM" "$DEFAULTS"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

# winify <forward-slash path> -> backslash path (simulate a Windows tool path).
winify() { printf '%s' "$1" | tr '/' '\\'; }

assert_eq() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "PASS [$label]"; PASS=$((PASS+1))
  else
    echo "FAIL [$label]: want [$want] got [$got]" >&2
    FAIL=$((FAIL+1)); FAILED_CASES="${FAILED_CASES}${label} "
  fi
}

# --- normalize_path unit tests --------------------------------------------
# shellcheck source=/dev/null
. "$LIB_NORM"
assert_eq "normalize backslash->slash" "C:/X/.claude/session" "$(normalize_path 'C:\X\.claude\session')"
assert_eq "normalize posix no-op" "/a/b/c" "$(normalize_path '/a/b/c')"
assert_eq "normalize idempotent posix" "$(normalize_path '/a/b/c')" "$(normalize_path "$(normalize_path '/a/b/c')")"
assert_eq "normalize idempotent win" "$(normalize_path 'C:\x\y')" "$(normalize_path "$(normalize_path 'C:\x\y')")"
assert_eq "normalize empty" "" "$(normalize_path '')"

# --- sandbox harness ------------------------------------------------------
make_sandbox() {
  local sb
  sb=$(mktemp -d)
  (
    cd "$sb" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    : > onboarding.yaml
    : > apexyard.projects.yaml
    git add onboarding.yaml apexyard.projects.yaml
    git commit -q -m "init"
  )
  mkdir -p "$sb/.claude/hooks" "$sb/.claude/session/tickets"
  cp "$HOOK_SRC" "$sb/.claude/hooks/require-active-ticket.sh"
  cp "$LIB_BASH" "$sb/.claude/hooks/_lib-detect-bash-write.sh"
  cp "$LIB_CFG"  "$sb/.claude/hooks/_lib-read-config.sh"
  cp "$LIB_NORM" "$sb/.claude/hooks/_lib-normalize-path.sh"
  cp "$DEFAULTS" "$sb/.claude/project-config.defaults.json"
  chmod +x "$sb/.claude/hooks/require-active-ticket.sh"
  echo "$sb"
}

# Canonical toplevel as the hook's `git rev-parse` will see it (handles the
# /tmp -> /private/tmp symlink on macOS so workspace-prefix matches line up).
sb_top() { ( cd "$1" && git rev-parse --show-toplevel ); }

run_case() {
  local label="$1" want_rc="$2" want_re="$3" input="$4" sb="$5"
  local out rc
  out=$(cd "$sb" && printf '%s' "$input" | bash .claude/hooks/require-active-ticket.sh 2>&1 >/dev/null)
  rc=$?
  rm -rf "$sb"
  if [ "$rc" != "$want_rc" ]; then
    echo "FAIL [$label]: want rc=$want_rc, got $rc (stderr: ${out:0:160})" >&2
    FAIL=$((FAIL+1)); FAILED_CASES="${FAILED_CASES}${label} "; return
  fi
  if [ -n "$want_re" ] && ! echo "$out" | grep -qE "$want_re"; then
    echo "FAIL [$label]: stderr did not match /$want_re/" >&2
    echo "    stderr: $out" >&2
    FAIL=$((FAIL+1)); FAILED_CASES="${FAILED_CASES}${label} "; return
  fi
  echo "PASS [$label]"; PASS=$((PASS+1))
}

edit_input() { jq -nc --arg p "$1" '{tool_name:"Edit", tool_input:{file_path:$p}}'; }
bash_input() { jq -nc --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}'; }

# B. Windows backslash .claude/session marker write (Edit) -> exempt (rc0).
sb=$(make_sandbox)
run_case "win backslash .claude/session marker exempt" 0 "" \
  "$(edit_input 'C:\proj\.claude\session\tickets\p')" "$sb"

# C. Windows backslash workspace edit WITH per-project marker -> allowed.
sb=$(make_sandbox)
top=$(sb_top "$sb")
cat > "$sb/.claude/session/tickets/ecom" <<EOF
repo=GOkasha/ecom
number=1
title=t
url=u
EOF
run_case "win backslash workspace edit w/ marker allowed" 0 "" \
  "$(edit_input "$(winify "$top/workspace/ecom/src/foo.ts")")" "$sb"

# D. Windows backslash workspace edit WITHOUT marker -> blocked (rc2).
sb=$(make_sandbox)
top=$(sb_top "$sb")
run_case "win backslash workspace edit no marker blocked" 2 "BLOCKED" \
  "$(edit_input "$(winify "$top/workspace/ecom/src/foo.ts")")" "$sb"

# E. rm of a .claude/session marker (forward slash) -> allowed (rc0).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "rm .claude/session marker (fwd) allowed" 0 "" \
  "$(bash_input "rm $top/.claude/session/tickets/p")" "$sb"

# F. rm of a .claude/session marker (backslash) -> allowed (rc0).
sb=$(make_sandbox)
run_case "rm .claude/session marker (win) allowed" 0 "" \
  "$(bash_input 'rm C:\proj\.claude\session\tickets\p')" "$sb"

# G. rm -rf .claude/session/ -> allowed (rc0).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "rm -rf .claude/session/ allowed" 0 "" \
  "$(bash_input "rm -rf $top/.claude/session/")" "$sb"

# H. rm mixing an exempt + a non-exempt target -> blocked (rc2).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "rm mixed exempt+nonexempt blocked" 2 "BLOCKED" \
  "$(bash_input "rm $top/.claude/session/tickets/p $top/src/foo.ts")" "$sb"

# I. rm of a non-exempt target -> blocked (rc2).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "rm non-exempt blocked" 2 "BLOCKED" \
  "$(bash_input "rm $top/src/foo.ts")" "$sb"

# J1. POSIX forward-slash regression: source edit, no marker -> blocked.
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "posix source edit no marker blocked" 2 "BLOCKED" \
  "$(edit_input "$top/src/foo.ts")" "$sb"

# J2. POSIX forward-slash .claude edit -> exempt.
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "posix .claude edit exempt" 0 "" \
  "$(edit_input "$top/.claude/session/tickets/p")" "$sb"

echo ""
echo "==================================="
echo "  PASS: $PASS   FAIL: $FAIL"
echo "==================================="
if [ "$FAIL" -gt 0 ]; then
  echo "Failed: $FAILED_CASES" >&2
  exit 1
fi
exit 0
