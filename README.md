# claude-with-agy

A [Claude Code](https://claude.com/claude-code) skill for delegating bulk / mechanical coding work to the **Antigravity CLI (`agy`, Gemini models)** in headless mode — on **Windows** — and auditing the result, so you spend fewer Claude tokens without losing control of the code.

Claude is the coordinator and auditor; `agy` does the cheap edits.

## What's inside

```
skills/claude-with-agy/
  SKILL.md                          # entry point: workflow + hard rules
  references/
    invocation.md                   # flags, modes, models, session reuse, the exit-code trap
    permissions.md                  # headless permission model + settings.json allow-rule syntax
    windows-and-claude-code.md      # Git Bash / PowerShell quoting, runner pattern, process hygiene
    prompt-patterns.md              # writing tasks Gemini Flash actually finishes
    audit-checklist.md              # verify every run; failure modes seen in practice
    cost-control.md                 # effort, parallelism, session reuse, when not to delegate
  scripts/run_agy.sh                # runner template (prompt from files, log + exit marker)
```

## Install

With the [`skills`](https://github.com/vercel-labs/skills) CLI (recommended):

```bash
# for the current project
npx skills add FaustoSoftware/claude-with-agy -a claude-code

# or globally (all projects)
npx skills add FaustoSoftware/claude-with-agy -g -a claude-code

# preview what would be installed
npx skills add FaustoSoftware/claude-with-agy --list
```

Manual alternative — copy the skill folder into your Claude Code skills directory:

```powershell
Copy-Item -Recurse skills\claude-with-agy $env:USERPROFILE\.claude\skills\
```

Then ask Claude Code something like *"use agy to adapt these tests, then audit"*.

## The five lessons that matter most

1. In `-p` mode every un-approved tool call is **auto-denied and aborts the run — with exit code 0**. Pre-approve exact commands in agy's `permissions.allow` (`command(<exact string>)`, `mcp(server/tool)`), and read the log, not the exit code.
2. Gemini Flash reaches for shell `grep`/`cat`/`Get-Content` and chains commands. Tell it, in the prompt, to use only its internal file tools and the listed commands, one at a time.
3. Never pass big prompts inline in Git Bash. Write them to files and launch through a runner script in the background.
4. Decide the design **before** delegating, keep tasks narrow with disjoint file scopes, and don't run many cold-start jobs at `--effort high`. Use `plan` mode, `--continue` and lower effort.
5. Treat agy's summary as a claim. Back up first, then run the tests yourself, diff against the backup, and grep for fabricated data.

## Notes

- Verified against `agy` 1.3.x on Windows 11 with Claude Code. Flag names and model ids may change: check `agy --help` and `agy models`.
- This repository contains no project code, credentials or personal paths; examples use placeholders.
- Licensed under the [MIT License](LICENSE).
