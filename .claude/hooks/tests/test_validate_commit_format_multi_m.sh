#!/bin/bash
# Tests for validate-commit-format.sh — first-`-m` subject extraction.
#
# Reproduces the bug from GOkasha/apexyard#7: the greedy
#   sed -nE "s/.*-m[[:space:]]+'([^']*)'.*/\1/p" | head -1
# matches the LAST `-m` argument because `.*-m` is greedy. With two `-m`
# flags (a common git pattern: `-m subject -m body`), the hook validates
# the BODY against the conventional-commit subject regex and blocks
# legitimate commits.
#
# Each case:
#   - builds an isolated sandbox with the hook
#   - pipes a synthetic PreToolUse JSON for a `git commit` command
#   - asserts the expected exit code (0 = pass, 2 = blocked)
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/validate-commit-format.sh"
LIB_CONFIG="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"

for f in "$HOOK_SRC" "$LIB_CONFIG"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

make_sandbox() {
  local sb
  sb=$(mktemp -d)
  (
    cd "$sb" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    : > onboarding.yaml
    git add onboarding.yaml
    git commit -q -m "init"
  ) >/dev/null 2>&1
  mkdir -p "$sb/.claude/hooks"
  cp "$HOOK_SRC"   "$sb/.claude/hooks/validate-commit-format.sh"
  cp "$LIB_CONFIG" "$sb/.claude/hooks/_lib-read-config.sh"
  chmod +x "$sb/.claude/hooks/validate-commit-format.sh"
  # Copy defaults so commit-type whitelist resolves.
  if [ -f "$SRC_ROOT/.claude/project-config.defaults.json" ]; then
    cp "$SRC_ROOT/.claude/project-config.defaults.json" "$sb/.claude/project-config.defaults.json"
  fi
  echo "$sb"
}

run_case() {
  local label="$1" cmd="$2" want_rc="$3"
  local sb; sb=$(make_sandbox)
  local input
  input=$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')
  local got_rc got_stderr
  got_stderr=$(cd "$sb" && echo "$input" | bash .claude/hooks/validate-commit-format.sh 2>&1 >/dev/null)
  got_rc=$?
  rm -rf "$sb"

  if [ "$got_rc" != "$want_rc" ]; then
    echo "FAIL [$label]: want rc=$want_rc, got $got_rc" >&2
    echo "    cmd: $cmd" >&2
    [ -n "$got_stderr" ] && echo "    stderr (first 4 lines):" >&2 && echo "$got_stderr" | head -4 | sed 's/^/      /' >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - $label"
    return 1
  fi
  PASS=$((PASS + 1))
  return 0
}

# --- Single -m forms (must keep working) ---
run_case "single-m-single-quoted-good" \
  "git commit -m 'docs(GH-7): fix windows hooks'" 0
run_case "single-m-double-quoted-good" \
  'git commit -m "docs(GH-7): fix windows hooks"' 0
run_case "single-m-bad-subject-blocked" \
  "git commit -m 'no-type-prefix subject'" 2

# --- Multi -m: good subject + plain body (this is THE bug case) ---
run_case "multi-m-good-first-bad-body" \
  "git commit -m 'docs(GH-7): fix windows hooks' -m 'Body line about something else entirely'" 0
run_case "multi-m-good-first-body-also-good-shape" \
  "git commit -m 'fix(#42): handle expired tokens' -m 'feat(#99): NOT the subject'" 0

# --- Negative: bad first subject must STILL be caught (no rule loosening) ---
run_case "multi-m-bad-first-good-shape-second" \
  "git commit -m 'totally malformed' -m 'docs(#7): the body looks fine but it is not the subject'" 2

# --- --message synonym (long form) ---
run_case "long-message-first-good" \
  "git commit --message 'docs(GH-7): long-form first' -m 'body'" 0
run_case "long-message-first-bad" \
  "git commit --message 'bad subject' -m 'docs(#7): body'" 2

# --- Mixed quoting (single-then-double, double-then-single) ---
run_case "mixed-quoting-single-then-double" \
  'git commit -m '"'"'docs(GH-7): mixed'"'"' -m "body line"' 0

# --- Heredoc-substitution: must still be short-circuited (existing behaviour) ---
# The hook intentionally bypasses validation on $(cat <<EOF ...) shapes
# because the actual subject is in the heredoc body, not the -m string.
run_case "heredoc-substitution-skipped" \
  "git commit -m \"\$(cat <<'EOF'
docs(GH-7): from heredoc
EOF
)\"" 0

echo ""
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "Failed cases:%b\n" "$FAILED_CASES"
  exit 1
fi
exit 0
