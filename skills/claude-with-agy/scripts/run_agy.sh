#!/usr/bin/env bash
# Runner template for headless agy jobs (Git Bash on Windows).
#
# Usage:   run_agy.sh <task-name>
# Expects: $WORK/header.md      shared rules/context for every task
#          $WORK/<task>.txt     the narrow task block
# Writes:  $WORK/<task>.log     agy output + a final "agy exit: N" marker
#
# Launch it from Claude Code's Bash tool with run_in_background=true; you get a
# notification when it ends. Remember: exit code 0 does NOT mean success —
# grep the log for "auto-denied" / "no output produced" (see references/).

set -u
WORK="${WORK:?set WORK to the directory holding header.md and the task files}"
REPO="${REPO:?set REPO to the repository root}"
MODEL="${MODEL:-gemini-3.8-flash-medium}"
EFFORT="${EFFORT:-medium}"
MODE="${MODE:-accept-edits}"   # accept-edits | auto | plan

TASK="${1:?task name required}"
cd "$REPO" || exit 1

PROMPT="$(cat "$WORK/header.md")
$(cat "$WORK/$TASK.txt")"

agy -p "$PROMPT" \
    --model "$MODEL" \
    --effort "$EFFORT" \
    --mode "$MODE" \
    --print-timeout 0 > "$WORK/$TASK.log" 2>&1

echo "agy exit: $?" >> "$WORK/$TASK.log"
