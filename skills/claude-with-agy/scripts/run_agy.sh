#!/usr/bin/env bash
# Runner template for headless agy jobs (Git Bash on Windows), with session reuse.
#
# Usage:   run_agy.sh <task-name>
# Expects: $WORK/header.md      shared rules/context (sent only on a COLD start)
#          $WORK/<task>.txt     the narrow task block (always sent)
# Writes:  $WORK/<task>.log     agy text output + stderr + a final "agy exit: N" marker
#          $WORK/<task>.jsonl   raw stream-json events (diagnosis, usage, denied_actions)
#          $WORK/session-$AREA.state   "<conversation_id> <context_tokens>" (only if AREA set)
#
# Session reuse (saves tokens: no repo re-read, no repeated header):
#   AREA=backend-tests run_agy.sh task1     # cold start, state file created
#   AREA=backend-tests run_agy.sh task2     # --conversation <id>, task block only
# The session is RETIRED (next run starts cold) when the last measured context is
# >= 80% of CTX_WINDOW, or when it shrank since the previous run (= compaction).
# Without AREA every run is cold, as before.
#
# Launch it from Claude Code's Bash tool with run_in_background=true; you get a
# notification when it ends. Remember: exit code 0 does NOT mean success — see the
# "VERDICT" line printed at the end of the log (denied actions / quota / compaction).

set -u
WORK="${WORK:?set WORK to the directory holding header.md and the task files}"
REPO="${REPO:?set REPO to the repository root}"
MODEL="${MODEL:-gemini-3.8-flash-medium}"
EFFORT="${EFFORT:-}"                # leave empty: the model tier suffix (-low/-medium/-high) already
                                    # sets the effort and a DIFFERENT --effort is rejected (exit 1)
MODE="${MODE:-accept-edits}"        # accept-edits | auto | plan
AREA="${AREA:-}"                    # set to reuse a warm session per work area
# Context window of the chosen model in tokens. NOT verified for agy models: the
# default is deliberately conservative (retires sessions early, never late).
CTX_WINDOW="${CTX_WINDOW:-200000}"
CTX_PCT="${CTX_PCT:-80}"

TASK="${1:?task name required}"
cd "$REPO" || exit 1
LOG="$WORK/$TASK.log"; RAW="$WORK/$TASK.jsonl"; ERR="$WORK/$TASK.err"
STATE="$WORK/session-$AREA.state"

CONV=""; PREV_TOK=0; WHY="cold start"
if [ -n "$AREA" ] && [ -f "$STATE" ]; then
  read -r CONV PREV_TOK < "$STATE"
  if [ $((PREV_TOK * 100)) -ge $((CTX_WINDOW * CTX_PCT)) ]; then
    WHY="session '$AREA' retired: context $PREV_TOK >= ${CTX_PCT}% of $CTX_WINDOW"; CONV=""
  else
    WHY="reusing session '$AREA' (context ~$PREV_TOK tokens)"
  fi
fi

if [ -n "$CONV" ]; then
  PROMPT="$(cat "$WORK/$TASK.txt")"
  SESSION_ARGS=(--conversation "$CONV")
else
  PROMPT="$(cat "$WORK/header.md")
$(cat "$WORK/$TASK.txt")"
  SESSION_ARGS=()
fi

EFFORT_ARGS=()
[ -n "$EFFORT" ] && EFFORT_ARGS=(--effort "$EFFORT")

agy -p "$PROMPT" \
    --model "$MODEL" "${EFFORT_ARGS[@]}" \
    --mode "$MODE" \
    --print-timeout 0 \
    --output-format stream-json \
    "${SESSION_ARGS[@]}" > "$RAW" 2> "$ERR"
CODE=$?

RESULT="$(grep '"event":"result"' "$RAW" | tail -n 1)"
NEW_CONV="$(printf '%s' "$RESULT" | sed -n 's/.*"conversation_id":"\([^"]*\)".*/\1/p')"
num() { printf '%s' "$RESULT" | sed -n "s/.*\"$1\":\([0-9]*\).*/\1/p"; }
# Heuristic context size from the result's usage. Observed: input_tokens sometimes
# includes the cached part and sometimes not; when it is smaller than cache_read_tokens
# it clearly excludes it, so add them. Approximate: good enough for a 80% guard.
IN="$(num input_tokens)"; CACHE="$(num cache_read_tokens)"
IN="${IN:-0}"; CACHE="${CACHE:-0}"
TOK="$IN"; [ "$IN" -lt "$CACHE" ] && TOK=$((IN + CACHE))

# Human-readable log: final response text, stderr, then the verdict.
{
  printf '%s' "$RESULT" | sed -n 's/.*"response":"\(.*\)","duration_seconds.*/\1/p' | sed 's/\\n/\n/g'
  cat "$ERR"
  echo "agy exit: $CODE"
  echo "session: $WHY; context now ~$TOK tokens"
} > "$LOG"

VERDICT="ok"
[ "$CODE" -ne 0 ] && VERDICT="AGY FAILED with exit $CODE (nothing edited; see $ERR and $RAW)"
grep -q '"denied_actions"' "$RAW" && VERDICT="DENIED ACTIONS (run is incomplete; fix allow-rules)"
grep -q -E 'auto-denied|no output produced' "$ERR" && VERDICT="DENIED ACTIONS (run is incomplete; fix allow-rules)"
grep -q -E 'RESOURCE_EXHAUSTED' "$ERR" "$RAW" 2>/dev/null && VERDICT="QUOTA EXHAUSTED (do not retry in a loop)"
[ -z "$RESULT" ] && [ "$VERDICT" = ok ] && VERDICT="NO RESULT EVENT (check $ERR)"

if [ -n "$AREA" ] && [ -n "$NEW_CONV" ]; then
  if [ -n "$CONV" ] && [ "$TOK" -lt "$PREV_TOK" ]; then
    VERDICT="$VERDICT; COMPACTED (context shrank $PREV_TOK -> $TOK): session retired"
    rm -f "$STATE"
  elif [ $((TOK * 100)) -ge $((CTX_WINDOW * CTX_PCT)) ]; then
    VERDICT="$VERDICT; context >= ${CTX_PCT}%: session will be retired"
    echo "$NEW_CONV $TOK" > "$STATE"
  else
    echo "$NEW_CONV $TOK" > "$STATE"
  fi
fi
echo "VERDICT: $VERDICT" >> "$LOG"
