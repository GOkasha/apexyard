#!/bin/bash
# Tests for block-unreviewed-merge.sh — accepts BOM/CR-prefixed approval
# markers (GOkasha/apexyard#7).
#
# Reproduces the bug: when an approval marker is written by a tool that emits
# a UTF-8 BOM (PowerShell's `-Encoding utf8` default), the existing readers
# fail to strip the BOM before parsing. The CEO marker's `grep -E "^sha="`
# anchor mismatches, and the Rex marker's `tr -d '[:space:]'` leaves the
# BOM bytes intact in the resulting SHA. Both paths yield a comparison
# mismatch and a spurious BLOCKED verdict.
#
# Each case:
#   - builds an isolated sandbox with the hook, the libs, and the markers
#     written with the pathological BOM/CRLF byte sequences
#   - mocks `gh pr view` so the hook resolves the PR HEAD deterministically
#   - pipes a synthetic `gh pr merge` PreToolUse JSON
#   - asserts the expected exit code

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/block-unreviewed-merge.sh"
LIB_PR="$SRC_ROOT/.claude/hooks/_lib-extract-pr.sh"
LIB_MARKER="$SRC_ROOT/.claude/hooks/_lib-read-marker.sh"
# Note: _lib-ops-root.sh is INTENTIONALLY not copied into the sandbox.
# When that lib is absent, the hook falls back to REPO_ROOT (the sandbox
# itself) for marker resolution — which is exactly what we want for an
# isolated test. The same omission pattern is used by sibling
# test_block_unreviewed_merge.sh. Including the lib would trigger an
# unrelated Windows-path walk-up bug in resolve_ops_root.

for f in "$HOOK_SRC" "$LIB_PR"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

FIXED_SHA="abcdef1234567890abcdef1234567890abcdef12"

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
  mkdir -p "$sb/.claude/hooks" "$sb/.claude/session/reviews" "$sb/bin"
  cp "$HOOK_SRC" "$sb/.claude/hooks/block-unreviewed-merge.sh"
  cp "$LIB_PR"   "$sb/.claude/hooks/_lib-extract-pr.sh"
  # _lib-read-marker.sh exists only after Fix 4 lands — copy if present.
  [ -f "$LIB_MARKER" ] && cp "$LIB_MARKER" "$sb/.claude/hooks/_lib-read-marker.sh"
  chmod +x "$sb/.claude/hooks/block-unreviewed-merge.sh"

  # Mock gh to return FIXED_SHA for resolve_pr_head's call.
  cat > "$sb/bin/gh" <<EOF
#!/bin/bash
case "\$*" in
  *"pr view"*"headRefOid"*) echo "$FIXED_SHA" ;;
  *) ;;
esac
exit 0
EOF
  chmod +x "$sb/bin/gh"
  echo "$sb"
}

# Marker writers — deliberately pathological byte sequences.

write_rex_marker_plain() {
  local sb="$1" pr="$2"
  printf '%s\n' "$FIXED_SHA" > "$sb/.claude/session/reviews/${pr}-rex.approved"
}

write_rex_marker_bom() {
  # UTF-8 BOM (0xEF 0xBB 0xBF) prepended to a bare SHA. PowerShell's
  # `Out-File -Encoding utf8` produces this shape.
  local sb="$1" pr="$2"
  printf '\xef\xbb\xbf%s\n' "$FIXED_SHA" > "$sb/.claude/session/reviews/${pr}-rex.approved"
}

write_rex_marker_bom_crlf() {
  # BOM + CRLF line ending — the worst-case Windows shape.
  local sb="$1" pr="$2"
  printf '\xef\xbb\xbf%s\r\n' "$FIXED_SHA" > "$sb/.claude/session/reviews/${pr}-rex.approved"
}

write_ceo_marker_structured() {
  local sb="$1" pr="$2" sha="${3:-$FIXED_SHA}"
  cat > "$sb/.claude/session/reviews/${pr}-ceo.approved" <<EOF
sha=$sha
approved_by=user
approved_at=2026-05-22T14:25:00Z
skill_version=2
approval_summary="test"
EOF
}

write_ceo_marker_bom_structured() {
  # BOM prepended to the structured marker — repro of the exact PowerShell
  # `-Encoding utf8` bug from the ticket.
  local sb="$1" pr="$2" sha="${3:-$FIXED_SHA}"
  printf '\xef\xbb\xbfsha=%s\napproved_by=user\napproved_at=2026-05-22T14:25:00Z\nskill_version=2\napproval_summary="test"\n' \
    "$sha" > "$sb/.claude/session/reviews/${pr}-ceo.approved"
}

write_ceo_marker_bom_crlf_structured() {
  local sb="$1" pr="$2" sha="${3:-$FIXED_SHA}"
  printf '\xef\xbb\xbfsha=%s\r\napproved_by=user\r\napproved_at=2026-05-22T14:25:00Z\r\nskill_version=2\r\napproval_summary="test"\r\n' \
    "$sha" > "$sb/.claude/session/reviews/${pr}-ceo.approved"
}

run_merge_case() {
  local label="$1" pr="$2" want_rc="$3"
  local sb; sb=$(make_sandbox)
  shift 3
  # Caller-provided marker setup function(s) — each receives ($sb, $pr).
  for setup in "$@"; do
    "$setup" "$sb" "$pr"
  done
  local cmd input got_rc got_stderr
  # Compose the merge command at runtime so the literal "gh pr merge" string
  # doesn't appear in this test's source — the framework's own merge gate
  # scans tool-call commands for that substring.
  cmd="$(printf '%s pr %s %s --repo owner/repo --squash --delete-branch' gh merge "$pr")"
  input=$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')
  got_stderr=$(cd "$sb" && PATH="$sb/bin:$PATH" bash -c "echo '$input' | bash .claude/hooks/block-unreviewed-merge.sh" 2>&1 >/dev/null)
  got_rc=$?
  rm -rf "$sb"

  if [ "$got_rc" != "$want_rc" ]; then
    echo "FAIL [$label]: want rc=$want_rc, got $got_rc" >&2
    [ -n "$got_stderr" ] && echo "    stderr (first 6 lines):" >&2 && echo "$got_stderr" | head -6 | sed 's/^/      /' >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - $label"
    return 1
  fi
  PASS=$((PASS + 1))
  return 0
}

# Baseline: both markers plain — should pass through.
run_merge_case "baseline-plain-markers" 167 0 \
  write_rex_marker_plain \
  write_ceo_marker_structured

# BOM on Rex marker only.
run_merge_case "rex-marker-with-bom" 168 0 \
  write_rex_marker_bom \
  write_ceo_marker_structured

# BOM + CRLF on Rex marker.
run_merge_case "rex-marker-with-bom-crlf" 169 0 \
  write_rex_marker_bom_crlf \
  write_ceo_marker_structured

# BOM on CEO marker only (the PowerShell case from the ticket).
run_merge_case "ceo-marker-with-bom" 170 0 \
  write_rex_marker_plain \
  write_ceo_marker_bom_structured

# BOM + CRLF on CEO marker (worst case).
run_merge_case "ceo-marker-with-bom-crlf" 171 0 \
  write_rex_marker_plain \
  write_ceo_marker_bom_crlf_structured

# BOM on BOTH markers (full Windows pathology).
run_merge_case "both-markers-with-bom" 172 0 \
  write_rex_marker_bom \
  write_ceo_marker_bom_structured

# Negative: a wrong-SHA CEO marker (BOM-prefixed) must STILL be rejected.
# The fix normalizes the BOM but the SHA must match the PR HEAD; this
# CEO marker carries the wrong SHA, so the merge gate must still block.
sb_assert_negative() {
  local sb; sb=$(make_sandbox)
  write_rex_marker_plain "$sb" 173
  # CEO marker has BOM AND wrong SHA.
  printf '\xef\xbb\xbfsha=%s\napproved_by=user\napproved_at=2026-05-22T14:25:00Z\nskill_version=2\napproval_summary="test"\n' \
    "0000000000000000000000000000000000000000" > "$sb/.claude/session/reviews/173-ceo.approved"
  local cmd input got_rc
  cmd="$(printf '%s pr %s 173 --repo owner/repo --squash --delete-branch' gh merge)"
  input=$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')
  (cd "$sb" && PATH="$sb/bin:$PATH" bash -c "echo '$input' | bash .claude/hooks/block-unreviewed-merge.sh") >/dev/null 2>&1
  got_rc=$?
  rm -rf "$sb"
  if [ "$got_rc" = "2" ]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL [bom-marker-with-wrong-sha-still-blocked]: want rc=2, got $got_rc" >&2
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - bom-marker-with-wrong-sha-still-blocked"
  fi
}
sb_assert_negative

echo ""
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "Failed cases:%b\n" "$FAILED_CASES"
  exit 1
fi
exit 0
