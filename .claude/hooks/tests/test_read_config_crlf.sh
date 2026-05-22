#!/bin/bash
# Tests for _lib-read-config.sh — CRLF/BOM normalization on Windows.
#
# Reproduces the bug from GOkasha/apexyard#7: when project-config.defaults.json
# is checked out with CRLF line endings (Windows default), `config_get` emits
# values that carry a trailing `\r`, which corrupts every downstream regex that
# uses the values in a character class or alternation.
#
# Each case:
#   - builds an isolated sandbox with the lib + a CRLF-line-ended config file
#   - sources the lib, calls config_get
#   - asserts the OUTPUT contains no carriage returns
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LIB_SRC="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"

if [ ! -f "$LIB_SRC" ]; then
  echo "FAIL: required source missing: $LIB_SRC" >&2
  exit 1
fi

PASS=0
FAIL=0
FAILED_CASES=""

# Build a sandbox with a CRLF-line-ended defaults file and a BOM-prefixed
# user override (the two pathological Windows inputs).
make_sandbox_crlf() {
  local sb
  sb=$(mktemp -d)
  mkdir -p "$sb/.claude/hooks"
  cp "$LIB_SRC" "$sb/.claude/hooks/_lib-read-config.sh"

  # Force the defaults file to have CRLF line endings. printf with \r\n
  # ensures the file looks like a Windows-checked-out copy.
  printf '{\r\n  "branch": {\r\n    "type_whitelist": ["feature","fix","chore","docs","perf"]\r\n  }\r\n}\r\n' \
    > "$sb/.claude/project-config.defaults.json"

  # Initialise a git repo so _config_repo_root() resolves.
  (
    cd "$sb" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    : > onboarding.yaml
    git add onboarding.yaml .claude/hooks/_lib-read-config.sh .claude/project-config.defaults.json
    git commit -q -m "init"
  ) >/dev/null 2>&1
  echo "$sb"
}

# Same, plus a BOM-prefixed override file to exercise that path.
make_sandbox_bom_override() {
  local sb
  sb=$(make_sandbox_crlf)
  printf '\xef\xbb\xbf{"commit": {"type_whitelist": ["feat","fix"]}}\n' \
    > "$sb/.claude/project-config.json"
  echo "$sb"
}

run_case() {
  local label="$1" sb="$2" filter="$3"
  local out
  out=$(cd "$sb" && bash -c ". .claude/hooks/_lib-read-config.sh && config_get '$filter'")
  # Did the output contain any CR bytes?
  if echo "$out" | grep -q $'\r'; then
    echo "FAIL [$label]: config_get output contains carriage return" >&2
    echo "    filter: $filter" >&2
    echo "    output bytes (od -c):" >&2
    echo "$out" | od -c | head -3 >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - $label"
    rm -rf "$sb"
    return 1
  fi
  # Confirm we actually GOT a value (not blanked by accident).
  if [ -z "$out" ]; then
    echo "FAIL [$label]: config_get returned empty (filter '$filter' should have matched)" >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - $label"
    rm -rf "$sb"
    return 1
  fi
  PASS=$((PASS + 1))
  rm -rf "$sb"
  return 0
}

# --- Case 1: CRLF defaults file → array-element output should be CR-free ---
sb=$(make_sandbox_crlf)
run_case "crlf-defaults-branch-types" "$sb" '.branch.type_whitelist[]'

# --- Case 2: CRLF defaults + paste join → joined output should be CR-free ---
sb=$(make_sandbox_crlf)
out=$(cd "$sb" && bash -c ". .claude/hooks/_lib-read-config.sh && config_get '.branch.type_whitelist[]' | paste -sd'|' -")
if echo "$out" | grep -q $'\r'; then
  echo "FAIL [crlf-defaults-paste-join]: joined output carries \\r between tokens" >&2
  echo "    output (od -c, first line):" >&2
  echo "$out" | od -c | head -1 >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - crlf-defaults-paste-join"
else
  PASS=$((PASS + 1))
fi
rm -rf "$sb"

# --- Case 3: BOM-prefixed override → merged read should still work, no BOM in output ---
sb=$(make_sandbox_bom_override)
out=$(cd "$sb" && bash -c ". .claude/hooks/_lib-read-config.sh && config_get '.commit.type_whitelist[]'")
# Should contain "feat" and "fix" (from the BOM override) with no BOM bytes.
if [ -z "$out" ]; then
  echo "FAIL [bom-override-read]: config_get returned empty — override likely failed to parse" >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - bom-override-read"
elif printf '%s' "$out" | od -An -c | head -1 | grep -qE '357|273|277'; then
  echo "FAIL [bom-override-read]: output contains UTF-8 BOM bytes" >&2
  echo "$out" | od -c | head -2 >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - bom-override-read"
elif ! echo "$out" | grep -q '^feat$' || ! echo "$out" | grep -q '^fix$'; then
  echo "FAIL [bom-override-read]: expected 'feat' and 'fix' in output, got:" >&2
  echo "$out" >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - bom-override-read"
else
  PASS=$((PASS + 1))
fi
rm -rf "$sb"

echo ""
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "Failed cases:%b\n" "$FAILED_CASES"
  exit 1
fi
exit 0
