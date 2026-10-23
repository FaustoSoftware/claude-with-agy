---
name: claude-with-agy
description: Delegate mechanical or bulk coding work from Claude Code to the Antigravity CLI (`agy`, Gemini models) in headless mode on Windows, then audit the result. Use when the user wants to save Claude tokens by having agy do edits (refactors, test adaptation, docs, mechanical migrations), asks to "use agy", "use Gemini", or needs to run several agy jobs and verify them. Also covers UI checks: agy can open its own Chrome (chrome-devtools MCP), navigate, click, take screenshots and describe them with Gemini Flash vision, so Claude spends fewer tokens on frontend review. Covers invocation flags, the permissions allow-list that headless mode requires, Windows/Git Bash quoting traps, prompt patterns that keep Gemini Flash on task, parallelism rules, cost control, and the audit checklist.
---

# Claude Code + agy (Antigravity CLI) on Windows

Claude is the **coordinator and auditor**; agy is the **cheap hands**. Claude decides the design, writes narrow task prompts, launches agy, and verifies everything afterwards. Never trust agy's own "done" table as proof.

Read the reference files on demand:

- `references/invocation.md` — flags, modes, models, session reuse, exit-code trap.
- `references/permissions.md` — headless permission model and the `settings.json` allow-list syntax. **Read this before the first run.**
- `references/windows-and-claude-code.md` — Git Bash / PowerShell quoting, runner script, background jobs, process hygiene.
- `references/prompt-patterns.md` — how to write tasks Gemini Flash actually finishes.
- `references/audit-checklist.md` — what to verify after every run and the failure modes seen in practice.
- `references/browser-and-screenshots.md` — screenshots / UI checks: why built-in browser tools fail in `-p`, the own-Chrome MCP setup and its allow-rules. `scripts/setup_agy_browser.sh` does the one-time registration.
- `references/cost-control.md` — effort, parallelism, session reuse, when NOT to use agy.
- `scripts/run_agy.sh` — runner template (prompt from files, log, exit marker).

## Where agy keeps its config (Windows)

Everything lives under `C:\Users\<you>\.gemini\antigravity-cli\` (confirm with `Test-Path`; tell the user this path whenever you ask them to edit something there):

| What | Where |
|---|---|
| Permissions allow-list (`permissions.allow`) and trusted workspaces | `settings.json` |
| MCP servers | managed with `agy mcp list / add / remove` (no need to edit files) |
| Conversations (for `--conversation <id>`) | `conversations\<id>.db` |
| Diagnostic log | `cli.log` |
| Sign-in credentials | `antigravity-oauth-token` — **never read, print or commit it** |

Do not confuse it with `C:\Users\<you>\.gemini\settings.json`, which belongs to the separate Gemini CLI, nor with the IDE's folders (`antigravity`, `antigravity-ide`). The browser profile used by the own-Chrome setup is `.gemini\antigravity-browser-profile`, and screenshots go wherever the task says (e.g. `.gemini\antigravity-shots`).

## Workflow

1. **Decide the design first.** Do not launch agy while a product/architecture decision is open. Re-running tasks after a design change was the single biggest waste of quota.
2. **Back up** the working tree (or make sure it is all committed/stashed by the user) so you can `diff` against the pre-agy state afterwards.
3. **Prepare permissions** (`references/permissions.md`): add exact-match allow rules for every command the task needs; nothing else will run.
4. **Write narrow task prompts** into files (never inline in the shell): a shared header (rules, allowed commands, scope) + one task block. 3–6 items per task, explicit file scope.
5. **Launch** via the runner script, in the background, one job per disjoint file set. Prefer the `-low`/`-medium` model tiers for mechanical work and `--mode plan` first if scope is unclear. **Reuse sessions**: related tasks in the same area go through the same warm session (`AREA=<name>` in the runner → `--conversation`), sending only the task block.
6. **Guard the session before every reuse**: context must be **< 80%** of the window and the session must **not be compacted** (context shrinking between runs = compaction). Otherwise start cold with the full header. Details and measurement: `references/cost-control.md`.
7. **Read the log, not the exit code.** A denied permission aborts the run but exits `0`; the runner prints a `VERDICT:` line (denied actions, quota, failure, compaction) — read it.
8. **Audit** (`references/audit-checklist.md`): full test suite yourself, type-check, diff against the backup, grep for fabricated data, review delicate files by hand.
9. **Fix small things yourself.** Re-launching agy for a 3-line fix costs more than doing it.
10. Do not let agy run any git write command. The human commits.

## Hard rules for the delegating Claude

- Audit means audit: **do not widen scope** ("while I'm here I added…"). If the user asked to review, report; if they asked to fix item X, fix X. Features added "because the report suggested it" were the main source of user frustration.
- Anything that changes visible UI copy/layout, public API contracts or product rules must be listed to the user explicitly, with before/after.
- **Simplification / "remove over-engineering" lenses apply to logic and code, not to UI design.** Tell agents explicitly never to delete or shrink screens, flows or components; when a screen shows data the backend doesn't provide yet, render empty/"—", don't remove the screen. Screens the user has already tested are product decisions.
- Never claim a thing was done unless you verified it (tests / grep / diff). Say what you did not verify.
