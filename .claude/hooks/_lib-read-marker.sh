#!/bin/bash
# _lib-read-marker.sh — shared reader for `.claude/session/reviews/*.approved`
# markers (and any future approval/audit markers that are file-resident, single-
# operator-authored, possibly written via Windows tools that prepend a UTF-8
# BOM or use CRLF line endings).
#
# Why this exists
# ---------------
# Two failure modes were observed during the GH-148 / GH-153 audit cleanup
# and tracked under me2resh/apexyard#7:
#
#   1. PowerShell's `Out-File -Encoding utf8` prepends a UTF-8 BOM
#      (0xEF 0xBB 0xBF) to the file's first line. The pre-fix readers used
#      `grep -E "^sha="` (CEO marker) and `tr -d '[:space:]'` (Rex marker);
#      neither stripped the BOM, so the resulting value contained 3 stray
#      bytes that broke SHA equality and the structured-field parse.
#
#   2. CRLF line endings on Windows leave `\r` at the end of every line
#      after a `cat`. The pre-fix readers didn't strip CR, so a CR-tainted
#      `sha=...\r` value never equaled the BOM-free PR-HEAD comparison value.
#
# Same shape as `_lib-extract-push-ref.sh` and `_lib-extract-pr.sh`: not a
# hook itself, sourced by hooks via `. "$(dirname "$0")/_lib-read-marker.sh"`.
#
# Usage
# -----
#   . "$(dirname "$0")/_lib-read-marker.sh"
#
#   # Structured key=value marker (CEO format):
#   sha=$(read_marker_field "$CEO_APPROVAL" sha)
#   approved_by=$(read_marker_field "$CEO_APPROVAL" approved_by)
#
#   # Bare-SHA marker (Rex format):
#   rex_sha=$(read_marker_sha "$REX_APPROVAL")

# normalize_marker <path>
#   Outputs the marker's bytes with the UTF-8 BOM stripped from line 1
#   and all CRs removed.
#   - Missing file → empty output, exit 0 (caller decides what missing means).
#   - Idempotent — running it twice yields the same output as once.
normalize_marker() {
  local f="$1"
  [ -f "$f" ] || return 0
  # `1s/^\xef\xbb\xbf//` strips the BOM only on line 1 (the only place it
  # can validly appear in UTF-8). `tr -d '\r'` strips CR anywhere. Both
  # tools are POSIX-portable and work in Git Bash + WSL + macOS + Linux.
  sed -e '1s/^\xef\xbb\xbf//' "$f" | tr -d '\r'
}

# read_marker_field <path> <key>
#   Echoes the value of `<key>=<value>` in the normalized marker.
#   First matching line wins (deterministic answer to a malformed file
#   with duplicate keys). Strips surrounding double quotes from the value
#   so quoted summaries with spaces round-trip cleanly.
#   - Missing file or missing key → empty output, exit 0.
read_marker_field() {
  local f="$1" key="$2"
  [ -f "$f" ] || return 0
  [ -n "$key" ] || return 0
  normalize_marker "$f" \
    | grep -E "^${key}=" \
    | head -1 \
    | sed -E "s/^${key}=//" \
    | sed -E 's/^"(.*)"$/\1/'
}

# read_marker_sha <path>
#   Echoes a bare-SHA marker (Rex format) with BOM, CR, and any other
#   whitespace stripped. Equivalent to the pre-fix `tr -d '[:space:]' < f`
#   plus a BOM strip — preserves the Rex marker's wire format while making
#   the value Windows-safe.
#   - Missing file → empty output, exit 0.
read_marker_sha() {
  local f="$1"
  [ -f "$f" ] || return 0
  normalize_marker "$f" | tr -d '[:space:]'
}
