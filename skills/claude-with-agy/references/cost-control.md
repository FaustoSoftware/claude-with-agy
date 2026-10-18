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
| Mechanical edit, rename, test adaptation, boilerplate | `-low` or `-medium` model tier (no separate `--effort`) |
| Ambiguous scope | `--mode plan` first (no edits), then a second, narrow `accept-edits` run |
| Several related tasks | One warm session per area (`--conversation <id>`, `AREA=` in the runner) while context < 80% and not compacted; or `--input-format stream-json` |
| Independent tasks on different files | Parallel is fine, but 2–3 jobs, not 8; keep prompts short |
| Tiny fix (< ~10 lines) | Do it yourself with Claude's edit tool |
| Delicate logic (auth, money, concurrency, migrations) | Do it yourself or review line by line |
| Large docs rewrite | Give a verified facts list + surgical-edit instruction; one session per document |

## Session reuse (default for related tasks)

A cold start re-pays the system prompt (~19k tokens measured on a trivial prompt) plus whatever the agent re-reads. A resumed session keeps that in cache: in a measured 2-turn probe the second turn read ~16k tokens from cache. So **reuse one session per work area** (backend tests, docs, one frontend module) and send only the new task block — not the header again.

But a reused session is only a saving while it stays healthy. Before every reuse, check:

1. **Context < 80% of the model's window.** Past that, answers degrade and auto-compaction kicks in.
2. **Not compacted.** Compaction replaces earlier steps with a summary: the agent forgets exact rules, file contents and the allowed-commands list. A compacted session must be retired, not trusted.
3. **Same area and same design.** Never carry a session across a changed design decision or into unrelated files.

If any check fails, start cold (with the full header) and keep the old one only for read-only follow-ups.

### How to measure (headless)

Run with `--output-format stream-json`. The `result` event carries `conversation_id` and `usage` (`input_tokens`, `cache_read_tokens`, …). Approximate context = `input_tokens`, plus `cache_read_tokens` when `input_tokens` is smaller than it (observed: input excludes the cached part in that case). **Compaction signal: context shrank compared with the previous run of the same session.** `scripts/run_agy.sh` does all of this: set `AREA=<name>`, it stores `session-<name>.state`, resumes with `--conversation`, retires the session at `CTX_PCT` (80) % of `CTX_WINDOW`, or when it shrinks.

Caveats, stated honestly: the model's real context window is **not exposed** by `agy` (`CTX_WINDOW` defaults to a conservative 200000 — set the real value if you know it), and `-p "/context"` / `-p "/usage"` do not work headless (the text is sent to the model as a prompt, which then asks for a shell command and gets denied). For an exact reading, open the conversation interactively and use `/context`; `/compact` exists in the interactive CLI (not tested headless).

Reuse per area, not per project. Sequential means no parallel speed-up — that is the price.

## Before launching, ask

1. Is the design fixed? 2. Is the scope closed and the prompt < a page of tasks? 3. Are the allow-rules in place? 4. Is there a backup? 5. Is this cheaper than doing it directly?
