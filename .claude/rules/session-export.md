# Session export / handoff

When this project's work is exported or handed off between sessions,
tools, or people — e.g. moved from one Claude surface to another, hand-off
to a different session, or a deliberate "package this up for someone else"
request — write a short manifest doc recording:

- **When** the export happened and **why** (the requester's own stated
  reason, verbatim if they gave one).
- **What's included** — a one-line pointer to what changed structurally
  versus the prior state (new folders, renamed/moved files), not a full
  content summary (that's what `CLAUDE.md` is for).
- **What's NOT included**, if anything was deliberately left out, and
  where it still lives if it might be needed later.
- Any environment/access difference the receiving session should know
  about (e.g. "the new session doesn't have access to X that the old one
  did").

Name it `<Project>_Export_Manifest_<yyyy_mm_dd_hh_mm_ss>.md` and place it
at the project root (or `.claude/docs/` if the project keeps its root
minimal) — it's a one-time record, not something that gets updated in
place like `CLAUDE.md`. A new export gets a new manifest file, not an edit
to the old one.

The point: a fresh session picking up an exported project should never
have to guess *why* it looks the way it does, or waste a round asking the
person to re-explain something they already explained once, elsewhere.
