# Invoking agy headless

```bash
agy -p "<prompt>" \
    --model gemini-3.8-flash-medium \
    --mode accept-edits \
    --print-timeout 0
```

The model tier (`-low` / `-medium` / `-high`) already sets the reasoning effort, so no `--effort` here (see Traps).

(Verified against `agy` 1.3.x; run `agy --help` and `agy models` to confirm names on your install — model ids change.)

| Flag | Meaning / advice |
|------|------------------|
| `-p` / `--print` | One prompt, non-interactive. Output is printed **only when the turn finishes**: the log stays empty while it works. |
| `--mode` | `accept-edits` (edits applied without asking), `auto`, `plan` (propose a plan first, no edits). Use `plan` when scope is ambiguous; use `accept-edits` for well-defined edits. |
| `--effort` | `low`, `medium`, `high`, `xhigh`, `max`. For the tiered Gemini models the tier suffix already sets it — omit the flag (see Traps). `high` everywhere burns quota fast. |
| `--model` | e.g. `gemini-3.8-flash-high`, `-medium`, `-low`. Check `agy models`. |
| `--print-timeout 0` | Wait until the turn completes (no wall-clock cap). |
| `--continue` / `-c` | Continue the most recent conversation — context already loaded, cheaper than a cold start. Ambiguous if the user also uses agy: prefer `--conversation <id>`. |
| `--conversation <id>` | Resume a specific conversation. The id is in the `init` / `result` events of `--output-format stream-json`. |
| `--input-format stream-json` | Multi-turn over stdin (one NDJSON message per line) in one process; needs `--output-format stream-json`. Good for chaining tasks in one warm session. |
| `--output-format stream-json` | Events per step, including token `usage`, the `conversation_id` and `denied_actions`. Use to measure context and to **diagnose** a run that stopped early. |
| `--add-dir` | Extra workspace directories. |
| `--dangerously-skip-permissions` | Auto-approves everything. Claude Code's auto-mode classifier may refuse to launch an agent with it — **do not work around that**; use allow-rules instead (see `permissions.md`). |

## Traps

- **The model tier already sets the effort.** `gemini-3.8-flash-low` + `--effort low` works, but `gemini-3.8-flash-medium` + `--effort low` fails at once with `--model ... conflicts with --effort=...` (exit `1`, nothing edited). Use the tier suffix *or* a matching `--effort`; simplest is to omit `--effort` for the tiered Gemini models.
- **Not every model accepts every flag.** `--effort` is rejected for non-Gemini models (e.g. `claude-sonnet-4-6`): the run fails immediately with `invalid model selection ... --effort is not supported for model`, exit code `1`, and nothing is edited. Check `agy models` and pass `--effort` only when you know the model takes it. Keep the effort flag optional in your runner script.
- **Quota exhausted** shows as `RESOURCE_EXHAUSTED (code 429): Individual quota reached ... Resets in …` with exit code `3` and no edits. Do not retry in a loop; report the reset time.
- **Machine-readable result.** With `--output-format stream-json` the final `result` event has `conversation_id`, `usage` and, when a permission was auto-denied, a `denied_actions` array — while `status` still says `SUCCESS`. The human-readable denial text goes to **stderr**. Slash commands such as `-p "/usage"` or `-p "/context"` are not executed in print mode: the text goes to the model as a prompt.
- **Exit code is `0` even when the run aborted** because a permission was auto-denied. The message looks like:
  `no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow ...`
  Always check `denied_actions` / grep for `auto-denied` / `no output produced` before believing a run succeeded.
- A run that "ends" with an agent saying it is *waiting for a background task* (it started a long command in the background) has effectively stopped: headless ends the turn and the work is left half done. Forbid background tasks in the prompt.
- Stopping the wrapper shell (e.g. Claude Code's task stop) may not kill the `agy.exe` child. Check with `Get-Process agy` and the command line (`Get-CimInstance Win32_Process`).
- A bare `agy.exe` process with no `-p` is an interactive session (probably the user's) — never kill it.
- agy writes files directly into the repo: back up first.
