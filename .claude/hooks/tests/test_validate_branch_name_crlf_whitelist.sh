#!/bin/bash
# Tests for validate-branch-name.sh — CRLF-resilient whitelist parsing.
#
# Reproduces the bug from GOkasha/apexyard#7: when the project-config defaults
# file is checked out with CRLF line endings, the TYPES variable built by
# `config_get | paste -sd'|' -` carries a `\r` after every type except the
# last, so the regex `^(feature\r|fix\r|...|perf)/` rejects every branch
# whose type isn't the final list entry (e.g. `chore/GH-153-...`).
#
# Each case:
#   - builds an isolated sandbox with the hook, the libs, AND a CRLF-line-ended
#     project-config.defaults.json (the pathological state)
#   - pipes a synthetic PreToolUse JSON for a `git push` command
#   - asserts the expected exit code
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/validate-branch-name.sh"
LIB_PUSH_REF="$SRC_ROOT/.claude/hooks/_lib-extract-push-ref.sh"
LIB_CONFIG="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"

for f in "$HOOK_SRC" "$LIB_PUSH_REF" "$LIB_CONFIG"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

make_sandbox_crlf_defaults() {
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
    # Force a non-conforming local branch so any fallback to `git branch
    # --show-current` would also fail validation — proves the hook is
    # using the push-command source ref, not local HEAD.
    git checkout -q -B not-conforming-branch
  ) >/dev/null 2>&1
  mkdir -p "$sb/.claude/hooks"
  cp "$HOOK_SRC"      "$sb/.claude/hooks/validate-branch-name.sh"
  cp "$LIB_PUSH_REF"  "$sb/.claude/hooks/_lib-extract-push-ref.sh"
  cp "$LIB_CONFIG"    "$sb/.claude/hooks/_lib-read-config.sh"
  chmod +x "$sb/.claude/hooks/validate-branch-name.sh"

  # The pathological config: CRLF line endings on every line. Force the
  # whitelist to include all the standard types so the test is deterministic.
  printf '{\r\n  "branch": {\r\n    "type_whitelist": ["feature","fix","refactor","chore","docs","test","spike","ci","build","perf"]\r\n  }\r\n}\r\n' \
    > "$sb/.claude/project-config.defaults.json"
  echo "$sb"
}

run_case() {
  local label="$1" cmd="$2" want_rc="$3"
  local sb; sb=$(make_sandbox_crlf_defaults)
  local input
  input=$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')
  local got_rc got_stderr
  got_stderr=$(cd "$sb" && echo "$input" | bash .claude/hooks/validate-branch-name.sh 2>&1 >/dev/null)
  got_rc=$?
  rm -rf "$sb"

  if [ "$got_rc" != "$want_rc" ]; then
    echo "FAIL [$label]: want rc=$want_rc, got $got_rc" >&2
    echo "    cmd: $cmd" >&2
    [ -n "$got_stderr" ] && echo "    stderr: $got_stderr" >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - $label"
    return 1
  fi
  PASS=$((PASS + 1))
  return 0
}

# The bug case — chore/ is NOT the last type in the whitelist, so a CRLF
# config makes the chore-prefixed branch get rejected. After the fix, it
# should pass.
run_case "chore-branch-with-crlf-config" \
  "git push origin chore/GH-153-license-posture-agdr" 0

# Same as above but the most common type — feature/. Was also broken.
run_case "feature-branch-with-crlf-config" \
  "git push origin feature/GH-42-add-csv-export" 0

# Negative case — a truly malformed branch must STILL be rejected.
# The fix only normalizes input; it doesn't loosen the rules.
run_case "malformed-branch-still-rejected" \
  "git push origin garbage-branch-name" 2

# Edge: type 'perf' (the last whitelist entry — only one that was passing
# pre-fix). Should still pass after fix.
run_case "perf-branch-still-passes" \
  "git push origin perf/GH-1-cache-tuning" 0

# Edge: type 'spike' (middle of the list — was broken). Should pass.
run_case "spike-branch-with-crlf-config" \
  "git push origin spike/GH-99-experiment" 0

echo ""
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "Failed cases:%b\n" "$FAILED_CASES"
  exit 1
fi
exit 0
