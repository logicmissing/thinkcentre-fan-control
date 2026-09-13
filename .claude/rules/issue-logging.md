# Issue logging

When a real bug is diagnosed (not a suspicion — something confirmed, with a
root cause), record it as a pair of documents in `.claude/docs/`:

1. **`GitHub_Issue_Log_<ShortBugName>_<yyyy_mm_dd_hh_mm_ss>.md`** — the full
   diagnostic record: symptom, how it was reproduced/confirmed, root cause,
   the fix, and live-test status (fixed-and-verified vs. fixed-but-not-yet-
   tested). Written for someone debugging a similar issue later.
2. **A plain-English companion doc** — the same fix, restated for the
   project's actual audience (see `coding-conventions.md`'s "write for the
   actual audience" rule) if that audience isn't a developer. Skip this
   second doc if the issue log is already written for the right audience.

Cross-reference both from `CLAUDE.md` Section 3 (the relevant workstream)
so the fix's status — live-tested or not — stays visible without having to
open `.claude/docs/` to check.

Never mark an issue resolved in `CLAUDE.md` until it's been confirmed by an
actual run, not just "the fix looks right." Say explicitly which state a
fix is in: diagnosed / fix written / fix live-tested.
