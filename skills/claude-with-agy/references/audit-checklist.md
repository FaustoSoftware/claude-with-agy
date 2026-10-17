# Auditing agy's work

Agy's final table is a claim, not evidence. After **every** run:

1. **Log first**: grep for `auto-denied`, `no output produced`, `waiting for`, `SKIPPED`, `PARTIAL`. Exit code 0 means nothing.
2. **Run the full test suite yourself**, alone (no other agent running). Compare with the count before.
3. **Type-check / build** the frontend (`tsc --noEmit`, bundler build). A plain-JS store file is not type-checked: run a syntax check on it (`node --check` on a `.mjs` copy).
4. **Diff against the backup** you took before launching (`diff -r`, ignoring CR/whitespace noise: `diff --strip-trailing-cr -w`). `git diff` alone hides what was already modified before the run.
5. **Grep for fabrications**: invented names/IDs/sizes/hashes, hard-coded demo data, default values that should be null, version strings, "TODO"/placeholder text that leaked into UI.
6. **Look at what was NOT asked**: files outside the declared scope, deleted tests, relaxed assertions, new dependencies, changed config, widened permissions (`superadmin` gets everything, etc.), changed defaults that alter behaviour.
7. **Read the delicate parts by hand**: auth/permissions, money math, state machines, migrations, concurrency, anything that decides who sees what.
8. **Visible UI changes** (copy, labels, categories, layout, pagination behaviour) — list them with before/after for the user; they are product decisions.
9. **Probe scripts** for the invariant that matters (e.g. tenant isolation): a 50-line script outside the repo that exercises the API and prints pass/fail is worth more than the agent's description.

## Failure modes seen in practice

| Symptom | Cause | Fix |
|---|---|---|
| Run "finished" but did nothing | Permission auto-denied at the first command; exit 0 | Add exact allow-rule; relaunch smaller |
| Half-done work, agent "waiting for background task" | Started a long command in background | Forbid background tasks; foreground only |
| Suite broken at the end | Agent changed a required field/fixture shape and didn't adapt the tests | Split "adapt tests" into its own narrow task per group of files |
| Race / collision bugs in generated helpers (e.g. sequence/code counters) | Naive read-then-write | Review concurrency code by hand; add a concurrent test |
| Fabricated defaults in UI/store | Agent filled gaps with plausible data | Rule "null/empty, never invent" + grep after |
| Silent semantic changes ("improved" behaviours) | Open-ended wording | Closed scope; audit the diff |
| Test passes that asserts old behaviour inverted | Agent edited the test to match its change | Read the changed assertions, not just the green bar |
| Another agent's file breaks your run | Parallel edits on one tree | Disjoint scopes; coordinator registers shared files; re-run alone |
| Design decision reversed mid-way | Decision was never fixed before launching | Decide first; keep a "decisions already taken" block in the header |

## After the audit

- Fix small leftovers yourself.
- Write the change report for the user: what changed per finding, which product decisions were made, what was **not** done, what you did **not** verify.
- Regenerate shared artifacts (API spec, lockfile) once, at the end, yourself.
- Leave `git add` / commit / push to the human.
