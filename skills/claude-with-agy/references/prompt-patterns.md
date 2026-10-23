# Writing tasks Gemini Flash finishes

## Structure: header file + task file

**Header (shared, stable)** — context, hard rules, allowed commands, forbidden things, final-report format.
**Task (one per job)** — exact file scope + numbered items.

Large prompts make Flash drift. Keep a task to ~3–6 items and a handful of files. Split big work into blocks (e.g. "A: service layer", "B: endpoints", "C: tests") and run them in sequence or in parallel with disjoint files.

## Header checklist

- Repo path and the 2–3 files to read first.
- **Scope**: "Edit only: …. Do not touch: …".
- **Commands**: the exact allowed strings, each to be run alone (see `permissions.md`). Say how to set the working directory without `cd`.
- **Tools**: internal file tools only for reading/searching; no MCP (or an explicit list); no background tasks.
- **Git**: read-only commands only. The human commits.
- **Data**: never edit/delete databases or generated artifacts; no network; don't install packages.
- **Design decisions already taken**: list them as facts ("do not discuss, implement"). Without this the agent re-litigates or invents.
- **No invented data**: if a value is unknown return null/empty/`—`; never fabricate names, IDs, legal text, sizes, hashes.
- **Parallel awareness**: other agents edit other files; do not fix failures in files outside scope; do not regenerate shared artifacts.
- **Don't finish early**: "Do not end your turn until every item is done or marked SKIPPED with the reason and the final table is printed."
- **Final report format**: `item | status (DONE/PARTIAL/SKIPPED) | files | test added | notes`, plus the final test result.

## Task patterns that worked

- *One behaviour per bullet* with the exact error code / field name / status code expected.
- *"Each fix has a test that fails before and passes after."*
- *Point at the evidence*: "see finding L-12 in REPORT.md" instead of re-pasting it.
- *Name the contract* (function signature, response shape) when two agents must agree on it in parallel.
- *Test adaptation tasks*: give the new rule once ("a tenant has one building; isolation tests must use two tenants") and list the files; the agent then rewrites mechanically.
- *Docs tasks*: give a "facts" list verified against the code, ask for surgical edits, and require a table of what was changed and what stayed doubtful.

## Anti-patterns

- Asking for "everything in the report" in one prompt.
- Leaving a design question open ("decide how to model X").
- Letting the prompt say "fix/improve" without a boundary — agents add features.
- Telling an agent to run the suite while others are mid-edit and then trusting its green/red.
- Re-launching the same job with a longer prompt after a permission abort instead of fixing the allow-list.

## Examples (anonymous)

**Short header + one bounded task** (`header.md` is sent only on a cold start; later tasks in a reused session send just the task block):

```text
# header.md
Rules: edit only the files listed in SCOPE. Use only your internal file tools to read/search.
The only shell command allowed is: npx tsc --noEmit  (run it alone, in the foreground).
No MCP tools, no background tasks, no git write commands. Do not change UI copy or layout.
If something is unclear, stop and say so; do not decide it yourself.

# task.txt
SCOPE: src/components/InvoiceTable.tsx, src/components/InvoiceTable.test.tsx
1. Rename prop `rowData` to `rows` in the component and every use inside SCOPE.
2. Update the test to the new prop name; do not change assertions.
3. Run `npx tsc --noEmit` and report its last line verbatim.
End with a table: file / change / anything doubtful.
```

**UI observation task** (browser MCP; observations, not opinions):

```text
Use only the chrome-devtools MCP server; read-only: do not press buttons that create, edit, vote, submit or delete.
1. navigate_page to http://localhost:5173/<route>, take_snapshot, take_screenshot, list_console_messages.
2. Report: main title, colors of the primary button and the status cards, anything overlapping or truncated, console errors, and the path where the screenshot was saved.
Answer only with what you see; do not guess.
```
