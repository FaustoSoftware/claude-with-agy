# Invoking agy headless

```bash
agy -p "<prompt>" \
    --model gemini-3.8-flash-high \
    --effort medium \
    --mode accept-edits \
    --print-timeout 0
```

(Verified against `agy` 1.3.x; run `agy --help` and `agy models` to confirm names on your install — model ids change.)

| Flag | Meaning / advice |
|------|------------------|
| `-p` / `--print` | One prompt, non-interactive. Output is printed **only when the turn finishes**: the log stays empty while it works. |
| `--mode` | `accept-edits` (edits applied without asking), `auto`, `plan` (propose a plan first, no edits). Use `plan` when scope is ambiguous; use `accept-edits` for well-defined edits. |
| `--effort` | `low\|medium\|high\|xhigh\|max`. Default to `low`/`medium` for mechanical work; `high` everywhere burns quota fast. |
| `--model` | e.g. `gemini-3.8-flash-high/medium/low`. Check `agy models`. |
| `--print-timeout 0` | Wait until the turn completes (no wall-clock cap). |
| `--continue` / `-c` | Continue the most recent conversation — context already loaded, cheaper than a cold start. |
| `--conversation <id>` | Resume a specific conversation. |
| `--input-format stream-json` | Multi-turn over stdin (one NDJSON message per line) in one process; needs `--output-format stream-json`. Good for chaining tasks in one warm session. |
| `--output-format stream-json` | Shows tool calls as they happen. Use to **diagnose** a run that stopped early. |
| `--add-dir` | Extra workspace directories. |
| `--dangerously-skip-permissions` | Auto-approves everything. Claude Code's auto-mode classifier may refuse to launch an agent with it — **do not work around that**; use allow-rules instead (see `permissions.md`). |

## Traps

- **Exit code is `0` even when the run aborted** because a permission was auto-denied. The log then contains a message like:
  `no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow ...`
  Always grep the log for `auto-denied` / `no output produced` before believing a run succeeded.
- A run that "ends" with an agent saying it is *waiting for a background task* (it started a long command in the background) has effectively stopped: headless ends the turn and the work is left half done. Forbid background tasks in the prompt.
- Stopping the wrapper shell (e.g. Claude Code's task stop) may not kill the `agy.exe` child. Check with `Get-Process agy` and the command line (`Get-CimInstance Win32_Process`).
- A bare `agy.exe` process with no `-p` is an interactive session (probably the user's) — never kill it.
- agy writes files directly into the repo: back up first.
