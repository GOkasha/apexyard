#!/bin/bash
# _lib-normalize-path.sh — shared path-separator normalization for the
# write-gate hooks (require-active-ticket.sh, require-migration-ticket.sh)
# and the bash-write detector.
#
# Why this exists
# ---------------
# On Git Bash for Windows, Claude Code's Edit / Write / MultiEdit tools
# hand the PreToolUse hooks a NATIVE backslash path via
# `tool_input.file_path` (e.g. `D:\Apexyard\apexyard\.claude\session\...`).
# Every path match in the write-gate hooks is forward-slash only
# (`.claude/*`, `*/.claude/*`, `"$WORKSPACE_DIR"/*`, the migration globs),
# so a backslash path matches NONE of them. The result is two opposite
# failures on Windows:
#
#   - over-block: `.claude/session/*` marker writes and registered
#     workspace source edits get blocked even though they should be
#     exempt / resolvable;
#   - under-detect: `prisma\schema.prisma` is not recognised as a
#     migration path, so the migration gate silently does not fire.
#
# The right-hand sides of those comparisons (REPO_ROOT, WORKSPACE_DIR,
# OPS_ROOT) come from `git rev-parse` / `$PWD`-walks and are already
# forward-slash on Git Bash. The mismatch is purely on the tool-supplied
# FILE_PATH (and the bash-extracted write target). Normalizing that ONE
# input at the hook boundary fixes every comparison without touching the
# matching logic or widening any exempt set.
#
# Same shape as `_lib-read-marker.sh` / `_lib-ops-root.sh`: not a hook
# itself, sourced by hooks via
# `. "$(dirname "$0")/_lib-normalize-path.sh"`. See GOkasha/apexyard#11
# (and the sibling Windows-portability fixes #7 CRLF/BOM, #9 ops-root
# walk-up).
#
# Usage
# -----
#   . "$(dirname "$0")/_lib-normalize-path.sh"
#   FILE_PATH=$(normalize_path "$FILE_PATH")

[ -n "${_LIB_NORMALIZE_PATH_SOURCED:-}" ] && return 0
_LIB_NORMALIZE_PATH_SOURCED=1

# normalize_path <path>
#   Echoes <path> with Windows backslash separators converted to forward
#   slashes. SEPARATOR-ONLY: it does not case-fold drive letters, collapse
#   repeated slashes, or resolve `.` / `..` — keeping the transform minimal
#   means it is a strict no-op on a typical POSIX path (no backslashes ->
#   unchanged) and is idempotent (running it twice yields the same result
#   as once). The only POSIX paths it alters are the pathological ones that
#   embed a literal backslash in a filename; that trade-off is accepted so
#   Windows paths work.
#   - Empty input -> empty output.
normalize_path() {
  printf '%s' "$1" | tr '\\' '/'
}
