# Windows + Claude Code specifics

## Where agy lives

Typically `%LOCALAPPDATA%\agy\bin\agy.exe`. Config under `C:\Users\<you>\.gemini\antigravity-cli\`.

## Never pass big prompts inline

Claude Code's Bash tool is Git Bash (POSIX). A multi-KB prompt with apostrophes, backticks, `$`, backslashes, accents and Markdown inside a heredoc or a double-quoted string breaks quoting in unpredictable ways (`unexpected EOF while looking for matching '`). Symptoms: the job "launches" but fails instantly with a shell syntax error.

Pattern that works:

1. Write the header and each task to **files** with the Write tool (`header.md`, `taskA.txt`).
2. Launch through a small runner script that reads them: see `scripts/run_agy.sh`.
3. Start the runner with the Bash tool's `run_in_background: true`; you get a notification when it ends.

## Do not poll with sleep

Claude Code blocks long foreground `sleep`. Use background launches + completion notifications, or a Monitor with an `until` loop that greps the logs for the exit marker.

## Paths

- Git Bash: `/c/Users/<you>/...`; PowerShell/agy prompts: `C:\Users\<you>\...`. Use the right one per tool. In prompts given to agy use Windows paths and PowerShell command forms.
- Python from a conda env: call the env's `python.exe` by absolute path; do not rely on `conda run` (slow, and the allow-rule must match exactly).
- PowerShell 5.1 has no `&&`; run exactly-allowed commands one per call.
- `git` prints `LF will be replaced by CRLF` warnings — harmless noise; pipe them away when you only need the stat.
- `gh` may be installed but not on the Bash PATH (`C:\Program Files\GitHub CLI\gh.exe`); call it by absolute path from PowerShell.

## Process hygiene

```powershell
Get-Process agy | Select Id, StartTime, CPU
Get-CimInstance Win32_Process -Filter "Name='agy.exe'" | Select ProcessId, CommandLine
```

Runs with `-p` are yours; a bare `agy.exe` is an interactive session — leave it. Stopping Claude Code's wrapper job may leave the child alive; verify.

## Logs

`agy -p ... > task.log 2>&1; echo "agy exit: $?" >> task.log` — the marker line lets a Monitor detect completion. Remember the log is empty until the turn ends.

## Parallel runs on one working tree

Several agy jobs edit the same checkout. Rules:

- Give each job a **disjoint file set** and say so in the prompt ("touch only these files").
- Shared registries (`__init__.py`, router registration in `main`, generated API specs, lockfiles) are edited by the coordinator, not by agents.
- Tell agents that a failing test caused by another agent's half-edited file is not theirs: report, don't fix.
- Test runs by several agents at once can yield transient errors (shared files, ports). Re-run alone before concluding anything.
