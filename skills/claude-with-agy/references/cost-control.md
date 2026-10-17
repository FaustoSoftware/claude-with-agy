# Cost control

A week of quota can disappear in a day. What drove it:

- ~40 cold-start runs, 8 of them in parallel, each re-reading the repo.
- `--effort high` on mechanical tasks.
- Re-running jobs after a design change (decide first!).
- Re-launching after permission aborts instead of fixing the allow-list once.
- Long headers repeated in every run.
- Agents re-reading very large documents/tests to change a few lines.

## Rules of thumb

| Situation | Do |
|---|---|
| Mechanical edit, rename, test adaptation, boilerplate | `--effort low` or `medium`, small model tier |
| Ambiguous scope | `--mode plan` first (no edits), then a second, narrow `accept-edits` run |
| Several related tasks | One warm session: `--continue`, or `--input-format stream-json` feeding tasks in sequence |
| Independent tasks on different files | Parallel is fine, but 2–3 jobs, not 8; keep prompts short |
| Tiny fix (< ~10 lines) | Do it yourself with Claude's edit tool |
| Delicate logic (auth, money, concurrency, migrations) | Do it yourself or review line by line |
| Large docs rewrite | Give a verified facts list + surgical-edit instruction; one session per document |

## Session reuse caveat

A long single session accumulates context and gets slower/less precise. Reuse per area (one session for the backend tests, one for docs), not one for the whole project. Sequential means no parallel speed-up — that is the price.

## Before launching, ask

1. Is the design fixed? 2. Is the scope closed and the prompt < a page of tasks? 3. Are the allow-rules in place? 4. Is there a backup? 5. Is this cheaper than doing it directly?
