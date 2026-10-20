# Proving a codex install works on real work

`codex --version`, `codex doctor` and codex's own completion summary all pass even when
the work is wrong or the agent hallucinated success. Prove the setup with a task that
touches several files and has an objective check.

## Recipe: project with a known gap

1. Write a small skeleton by hand — a package, a CLI entry point and a test file — whose
   current behaviour is deliberately incomplete. Commit it.
2. Run the baseline suite yourself and record the test count.
3. Delegate one **bounded** feature, stating the constraint set explicitly, e.g.
   "extend `parse_duration` to compound durations (`1h30m`, `2d3h`), support negatives,
   spaces and case, add tests, keep the CLI unchanged, and run the full suite".
   A bounded brief is what makes the result checkable.
4. Launch with `pty=true` and in the background so a long run does not hit the
   foreground timeout; poll with the process tool.
5. Re-check independently — never trust the summary:
   - `git diff --stat` to see what actually changed
   - re-run the test suite yourself and compare the count to baseline
   - exercise the CLI over a table of inputs **including invalid ones**, and check the
     arithmetic by hand rather than by reading the agent's explanation
6. Report your own diff and results, not codex's summary.

## Why gap-first

A task with a known gap has an objective pass/fail: the new behaviour either appears in
`git diff` and the new tests pass, or it does not. A prompt like "say PONG" proves only
that the transport works — it says nothing about whether the agent can read a codebase,
edit several files consistently, and run a test suite.

## Sizing the fixture

Keep it small enough to finish in one background run (a handful of files, one test
module). The point is to exercise the pipeline end to end, not to build something
useful — the fixture is throwaway.
