#!/bin/bash
# Unit tests for _lib-read-marker.sh — the BOM/CR normalization library
# introduced for GOkasha/apexyard#7.
#
# Functions under test:
#   - normalize_marker <path>     → bytes with BOM stripped from line 1 + all CRs removed
#   - read_marker_field <path> <key> → echoes value of `key=value`, first match wins
#   - read_marker_sha <path>      → echoes a bare-SHA marker (Rex format) BOM/CR-stripped
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LIB_SRC="$SRC_ROOT/.claude/hooks/_lib-read-marker.sh"

if [ ! -f "$LIB_SRC" ]; then
  echo "FAIL: required source missing: $LIB_SRC" >&2
  echo "(This test runs only after the fix lands. Confirming the library file is in place.)" >&2
  exit 1
fi

# shellcheck disable=SC1090,SC1091
. "$LIB_SRC"

PASS=0
FAIL=0
FAILED_CASES=""

assert_eq() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL [$label]:" >&2
  echo "    want: [$want]" >&2
  echo "    got:  [$got]" >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - $label"
  return 1
}

assert_empty() {
  local label="$1" got="$2"
  if [ -z "$got" ]; then
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL [$label]: expected empty, got [$got]" >&2
  FAIL=$((FAIL + 1))
  FAILED_CASES="${FAILED_CASES}\n  - $label"
  return 1
}

# --- normalize_marker ---

# 1. plain content
tmp=$(mktemp)
printf 'sha=abc123\napproved_by=user\n' > "$tmp"
out=$(normalize_marker "$tmp")
assert_eq "normalize-plain" 'sha=abc123
approved_by=user' "$out"
rm -f "$tmp"

# 2. BOM only on line 1
tmp=$(mktemp)
printf '\xef\xbb\xbfsha=abc123\napproved_by=user\n' > "$tmp"
out=$(normalize_marker "$tmp")
assert_eq "normalize-bom-line-1" 'sha=abc123
approved_by=user' "$out"
rm -f "$tmp"

# 3. CR only (CRLF line endings)
tmp=$(mktemp)
printf 'sha=abc123\r\napproved_by=user\r\n' > "$tmp"
out=$(normalize_marker "$tmp")
assert_eq "normalize-crlf-only" 'sha=abc123
approved_by=user' "$out"
rm -f "$tmp"

# 4. BOM + CRLF (worst-case Windows)
tmp=$(mktemp)
printf '\xef\xbb\xbfsha=abc123\r\napproved_by=user\r\n' > "$tmp"
out=$(normalize_marker "$tmp")
assert_eq "normalize-bom-crlf" 'sha=abc123
approved_by=user' "$out"
rm -f "$tmp"

# 5. Missing file → empty output, no error.
out=$(normalize_marker "/nonexistent/$$/path")
assert_empty "normalize-missing-file" "$out"

# --- read_marker_field ---

# 6. Plain key=value
tmp=$(mktemp)
printf 'sha=deadbeef\napproved_by=user\nskill_version=2\n' > "$tmp"
assert_eq "field-plain-sha"          "deadbeef" "$(read_marker_field "$tmp" sha)"
assert_eq "field-plain-approved_by"  "user"     "$(read_marker_field "$tmp" approved_by)"
assert_eq "field-plain-skill_version" "2"       "$(read_marker_field "$tmp" skill_version)"
rm -f "$tmp"

# 7. BOM-prefixed key=value
tmp=$(mktemp)
printf '\xef\xbb\xbfsha=deadbeef\napproved_by=user\nskill_version=2\n' > "$tmp"
assert_eq "field-bom-sha"          "deadbeef" "$(read_marker_field "$tmp" sha)"
assert_eq "field-bom-approved_by"  "user"     "$(read_marker_field "$tmp" approved_by)"
rm -f "$tmp"

# 8. BOM + CRLF key=value
tmp=$(mktemp)
printf '\xef\xbb\xbfsha=deadbeef\r\napproved_by=user\r\nskill_version=2\r\n' > "$tmp"
assert_eq "field-bom-crlf-sha"  "deadbeef" "$(read_marker_field "$tmp" sha)"
rm -f "$tmp"

# 9. Quoted value (double-quoted strings get unquoted)
tmp=$(mktemp)
printf 'sha=deadbeef\napproval_summary="This is a longer note with spaces"\n' > "$tmp"
assert_eq "field-quoted-value" "This is a longer note with spaces" \
  "$(read_marker_field "$tmp" approval_summary)"
rm -f "$tmp"

# 10. Malformed (no =) → empty
tmp=$(mktemp)
printf 'this is not a key=value pair\nsomething else\n' > "$tmp"
out=$(read_marker_field "$tmp" sha)
assert_empty "field-malformed-no-equals" "$out"
rm -f "$tmp"

# 11. Missing key → empty
tmp=$(mktemp)
printf 'sha=deadbeef\n' > "$tmp"
out=$(read_marker_field "$tmp" approved_by)
assert_empty "field-missing-key" "$out"
rm -f "$tmp"

# 12. First-match-wins on duplicate keys (deterministic answer to malformed input)
tmp=$(mktemp)
printf 'sha=FIRST\nsha=SECOND\n' > "$tmp"
assert_eq "field-first-match-wins" "FIRST" "$(read_marker_field "$tmp" sha)"
rm -f "$tmp"

# --- read_marker_sha ---

# 13. Plain bare SHA
tmp=$(mktemp)
printf '%s\n' "abcdef1234567890abcdef1234567890abcdef12" > "$tmp"
assert_eq "sha-plain" "abcdef1234567890abcdef1234567890abcdef12" "$(read_marker_sha "$tmp")"
rm -f "$tmp"

# 14. BOM-prefixed bare SHA
tmp=$(mktemp)
printf '\xef\xbb\xbf%s\n' "abcdef1234567890abcdef1234567890abcdef12" > "$tmp"
assert_eq "sha-bom" "abcdef1234567890abcdef1234567890abcdef12" "$(read_marker_sha "$tmp")"
rm -f "$tmp"

# 15. BOM + CRLF bare SHA
tmp=$(mktemp)
printf '\xef\xbb\xbf%s\r\n' "abcdef1234567890abcdef1234567890abcdef12" > "$tmp"
assert_eq "sha-bom-crlf" "abcdef1234567890abcdef1234567890abcdef12" "$(read_marker_sha "$tmp")"
rm -f "$tmp"

# 16. Trailing whitespace stripped (existing behaviour preserved)
tmp=$(mktemp)
printf '%s   \n\n' "abcdef1234567890abcdef1234567890abcdef12" > "$tmp"
assert_eq "sha-trailing-whitespace" "abcdef1234567890abcdef1234567890abcdef12" "$(read_marker_sha "$tmp")"
rm -f "$tmp"

# 17. Missing file → empty
out=$(read_marker_sha "/nonexistent/$$/path")
assert_empty "sha-missing-file" "$out"

echo ""
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "Failed cases:%b\n" "$FAILED_CASES"
  exit 1
fi
exit 0
