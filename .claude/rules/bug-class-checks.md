# Recurring bug-class checks

When a bug you fix turns out to be an instance of a *pattern* that could
recur elsewhere in the codebase (not just a one-off mistake), name the
pattern explicitly and check for it before the next delivery — don't just
fix the one instance and move on.

In practice:

1. Describe the bug class in one sentence (e.g. "a `GoTo <label>` whose
   label doesn't exist in the same procedure's scope," "a generated sheet/
   file name that can exceed the platform's length limit").
2. Sweep the rest of the codebase for the same pattern — a quick script if
   the check is mechanical, otherwise a deliberate manual read of anywhere
   the same shape of code appears.
3. Record the bug class here or in `.claude/docs/` once it's named, so
   future changes can be checked against it too, and so "have we seen this
   before" has an answer.
4. Before delivering a new multi-file or multi-procedure change, run
   through the known bug classes listed here as a checklist.

Keep this file's list current — add a bug class the first time it's found,
and note here if a scanner/script exists for it and where.

## Known bug classes for this project

### 1. A timestamp written in one timezone, read in another

`versioning-and-archival.md` says every generated filename carries a
timestamp in the project's own timezone. Any code that later parses one
of those filenames must parse it in that same timezone. A cloud
container runs on UTC, so a plain `date -d "<parsed timestamp>"` (or a
`git log --since=...` with the wrong offset attached) reads the value
hours newer than it really is.

Found in `.claude/hooks/dream-check.sh`, which compares a
`dream-proposal-<timestamp>.md` filename against the current time to
decide whether a `/dream` pass is due, and also passes that timestamp to
`git log --since=` to count commits since it. Both calls originally
hardcoded `Asia/Singapore` / `+08:00` directly in the script — a second
copy of the same constant already stated in `versioning-and-archival.md`,
free to drift out of sync with it.

**Resolution now in place:** the timezone is defined exactly once, in
`.claude/project.env` as `PROJECT_TZ`. `versioning-and-archival.md` and
`.claude/hooks/dream-check.sh` both read it from there — the hook parses
the file with `grep`/`sed`, never `source`s it — and the hook derives its
numeric git `--since` offset (e.g. `+0800`) from that same `PROJECT_TZ`
value with `date +%z`, instead of hardcoding an offset.

**Check before delivery:** grep for `date -d`, and for git's `--since` /
`--until` with a timezone offset attached — both are forms this bug can
take, and grepping only `date -d` misses the second. For each hit, confirm
it reads `PROJECT_TZ` from `.claude/project.env` rather than hardcoding a
zone name or numeric offset. The bug is silent — it produces a plausible
number that is simply wrong.

### 2. A mechanism that stores state in a gitignored file

This project's operator works only in Claude Code on the web, where the
container is rebuilt and the repository re-cloned for every session (see
`.claude/docs/about-me.md`). A gitignored file therefore never survives
to the next session.

Found in `.claude/hooks/dream-check.sh`, which kept its staleness clock
in a gitignored `dream-state.txt`. The file was always missing at
session start, so the hook took its "first run" branch every time and
never reported anything. Fixed by deriving the clock from committed
content instead, and deleting the state file.

**Check before delivery:** for anything that must remember a fact
between sessions, confirm the fact lives in a committed file, or can be
derived from one. A gitignored runtime file is not memory here.

### 3. An instruction that assumes a capability the operator's surface does not have

The operator works only in Claude Code on the web. Documentation and
rules written with a terminal in mind can tell them to run a command,
install something, or write to a location that does not exist on the
web — and it only fails when they actually try it.

Found in two places. `README.md` told the operator to run
`/plugin install ...`, which is not available in cloud sessions at all
(nor is `/reload-plugins`). `.claude/rules/model-delegation.md`
recommended `/clear`, which does not work on the web, and described
`/model` as opening a picker, which it does not do there.

**Resolution now in place:** both files corrected. Each command's web
status is now stated directly. The two the documentation did not cover
either way, `/usage` and `/rewind`, were then run in a real web session
— both work, and are recorded as confirmed by that test rather than by
the docs.

**Check before delivery:** before writing an instruction that tells the
operator to run a command, install a tool, or use a file location,
confirm it exists on the web surface. Terminal-only slash commands
(`/plugin`, `/reload-plugins`, `/resume`, `/clear`), anything needing a
shell the operator
does not have, and anything writing to a global path such as
`~/.claude/` are the usual cases. When the answer is not documented,
say it is unverified rather than recommending it.

This class is related to bug class 2 but distinct: class 2 is about
state not surviving between sessions; this one is about a capability
not existing on the surface at all.
