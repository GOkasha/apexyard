#!/bin/bash
# Tests for the Windows path-normalization fix (GOkasha/apexyard#11) in
# require-migration-ticket.sh.
#
# The bug: on Git Bash for Windows the Edit/Write tools hand a backslash
# FILE_PATH, and `is_migration_path` matches forward-slash globs only, so a
# backslash `prisma\schema.prisma` slipped PAST the migration gate (the gate
# silently did not fire — a safety gap). After normalization the gate must
# fire on the Windows path exactly as it does on the POSIX path.
#
# All "gate fires" cases assert a block at Gate 1 (no active ticket marker),
# which happens BEFORE any `gh` call — so the test needs no network/auth.
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/require-migration-ticket.sh"
LIB_NORM="$SRC_ROOT/.claude/hooks/_lib-normalize-path.sh"
LIB_BASH="$SRC_ROOT/.claude/hooks/_lib-detect-bash-write.sh"

for f in "$HOOK_SRC" "$LIB_NORM" "$LIB_BASH"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

winify() { printf '%s' "$1" | tr '/' '\\'; }

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
  cp "$HOOK_SRC" "$sb/.claude/hooks/require-migration-ticket.sh"
  cp "$LIB_NORM" "$sb/.claude/hooks/_lib-normalize-path.sh"
  cp "$LIB_BASH" "$sb/.claude/hooks/_lib-detect-bash-write.sh"
  chmod +x "$sb/.claude/hooks/require-migration-ticket.sh"
  echo "$sb"
}

sb_top() { ( cd "$1" && git rev-parse --show-toplevel ); }

run_case() {
  local label="$1" want_rc="$2" want_re="$3" input="$4" sb="$5"
  local out rc
  out=$(cd "$sb" && printf '%s' "$input" | bash .claude/hooks/require-migration-ticket.sh 2>&1 >/dev/null)
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

# M1. Backslash prisma/schema.prisma, no marker -> migration gate FIRES (rc2).
#     This is the regression the fix closes: pre-fix the backslash path was
#     not recognised as a migration and the hook exited 0.
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "win backslash prisma schema fires migration gate" 2 "database migration" \
  "$(edit_input "$(winify "$top/prisma/schema.prisma")")" "$sb"

# M2. Forward-slash prisma/schema.prisma, no marker -> fires (regression).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "posix prisma schema fires migration gate" 2 "database migration" \
  "$(edit_input "$top/prisma/schema.prisma")" "$sb"

# M3. Backslash .claude/session path -> exempt, hook is a no-op (rc0).
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "win backslash .claude exempt from migration gate" 0 "" \
  "$(edit_input "$(winify "$top/.claude/session/x")")" "$sb"

# M4. Backslash non-migration source path -> not a migration, no-op (rc0).
#     Confirms normalization didn't widen the migration matcher onto
#     ordinary source files.
sb=$(make_sandbox); top=$(sb_top "$sb")
run_case "win backslash src file is not a migration" 0 "" \
  "$(edit_input "$(winify "$top/src/foo.ts")")" "$sb"

echo ""
echo "==================================="
echo "  PASS: $PASS   FAIL: $FAIL"
echo "==================================="
if [ "$FAIL" -gt 0 ]; then
  echo "Failed: $FAILED_CASES" >&2
  exit 1
fi
exit 0
