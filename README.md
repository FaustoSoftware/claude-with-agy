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
    browser-and-screenshots.md      # screenshots/UI checks: own-Chrome MCP setup + allow-rules
    cost-control.md                 # effort, parallelism, session reuse, when not to delegate
  scripts/run_agy.sh                # runner: prompt from files, session reuse, VERDICT line
  scripts/setup_agy_browser.sh      # one-time: register chrome-devtools MCP, print allow-rules
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

## One-time setup (manual, on purpose)

Installing the skill only copies files. It never edits agy's settings, permissions or MCP servers, and Claude Code's own safety guard may refuse to edit them for you. Permissions are your decision, so do these steps yourself. Replace `<you>` with your Windows user name.

**1. Prerequisites**

- `agy` installed and signed in (`agy --help`, `agy models` work). Node.js if you want the browser setup (it runs through `npx`). Google Chrome for screenshots.
- Git Bash is what Claude Code's Bash tool uses; PowerShell is what agy's `run_command` uses.

**2. Allow-list for headless runs**

In `-p` mode agy cannot ask, so anything not pre-approved is denied and the run aborts with exit `0`. Edit `C:\Users\<you>\.gemini\antigravity-cli\settings.json` and add only what your tasks need:

```json
{
  "permissions": {
    "allow": [
      "command(git status)",
      "command(git diff --stat)",
      "command(npx tsc --noEmit)"
    ]
  }
}
```

Rules are **exact matches**: `command(...)` needs the full command string, `mcp(server/tool)` one tool. Any extra argument, `cd`, `;`, `&&`, pipe or redirect makes it a different command. Run once, read the `auto-denied` message (or the `denied_actions` field with `--output-format stream-json`), and add that exact rule if you agree with it. Do not use `--dangerously-skip-permissions`.

**3. Optional: screenshots and UI checks (own Chrome, like the Antigravity IDE)**

agy's built-in browser tools do not work in `-p`. Register a separate MCP server that launches its own Chrome with its own profile:

```bash
bash skills/claude-with-agy/scripts/setup_agy_browser.sh        # default viewport 1920x1080
```

Then paste the printed rules into `permissions.allow`:

```json
"mcp(chrome-devtools/list_pages)",
"mcp(chrome-devtools/new_page)",
"mcp(chrome-devtools/navigate_page)",
"mcp(chrome-devtools/take_screenshot)",
"mcp(chrome-devtools/take_snapshot)",
"mcp(chrome-devtools/list_console_messages)",
"execute_url(localhost)",
"mcp(chrome-devtools/click)",
"mcp(chrome-devtools/fill)",
"mcp(chrome-devtools/wait_for)"
```

Clicks, `fill` and `wait_for` are part of the main list because navigating a real app needs them. They let agy **change data in the app under test** (vote, submit, delete): use test data and say in the prompt which buttons are off limits. `evaluate_script` (arbitrary JavaScript in the page) is left out on purpose and is not needed for clicks. The browser uses `~.geminintigravity-browser-profile`, not your everyday Chrome profile, so it has none of your logins. Do **not** enable `chrome://inspect/#remote-debugging` on your daily Chrome for this. Details and what was tested: `skills/claude-with-agy/references/browser-and-screenshots.md`. Undo with `agy mcp remove chrome-devtools`.

**4. Check it works**

```bash
agy -p "Reply with the word OK. Use no tools." --model gemini-3.8-flash-low --mode plan --output-format stream-json
```

You should see a `result` event with `"status":"SUCCESS"` and no `denied_actions`. Model ids change: take them from `agy models`.

**5. Git stays with you**

The skill tells Claude never to let agy run git write commands. You review the diff and run `git commit` / `git push` yourself.

## The five lessons that matter most

1. In `-p` mode every un-approved tool call is **auto-denied and aborts the run — with exit code 0**. Pre-approve exact commands in agy's `permissions.allow` (`command(<exact string>)`, `mcp(server/tool)`), and read the log, not the exit code.
2. Gemini Flash reaches for shell `grep`/`cat`/`Get-Content` and chains commands. Tell it, in the prompt, to use only its internal file tools and the listed commands, one at a time.
3. Never pass big prompts inline in Git Bash. Write them to files and launch through a runner script in the background.
4. Decide the design **before** delegating, keep tasks narrow with disjoint file scopes, and don't run many cold-start jobs at `--effort high`. Use `plan` mode, reuse sessions (`--conversation`) while their context stays under 80% and uncompacted, and lower model tiers.
5. Treat agy's summary as a claim. Back up first, then run the tests yourself, diff against the backup, and grep for fabricated data.

## Notes

- Verified against `agy` 1.3.x on Windows 11 with Claude Code. Flag names and model ids may change: check `agy --help` and `agy models`.
- This repository contains no project code, credentials or personal paths; examples use placeholders.
- Licensed under the [MIT License](LICENSE).
