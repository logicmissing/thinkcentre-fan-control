# Versioning and archival

## File naming

Every versioned working file (code module, generated doc, generated
workbook — anything that gets revised over the project's life) is named:

```
<name>_v<major>_<minor>_<patch>_<yyyy_mm_dd_hh_mm_ss>
```

or, for files that don't carry a meaningful semantic version (a one-off
report, a dated snapshot):

```
<name>_<yyyy_mm_dd_hh_mm_ss>
```

**The timestamp uses the project's own timezone, not local server
time.** That timezone is not hardcoded here — it lives in one place,
`.claude/project.env`, as `PROJECT_TZ`, set once by
`/bootstrap-project` to the project owner's own IANA timezone name.
Its value right now is `Asia/Singapore` (UTC+8). Generate a timestamp
by reading it rather than typing a zone name:

```bash
TZ="$(sed -n 's/^PROJECT_TZ=//p' .claude/project.env)" date +"%Y_%m_%d_%H_%M_%S"
```

Do not hardcode a timezone anywhere else. `.claude/hooks/dream-check.sh`
reads this same `PROJECT_TZ` value rather than carrying its own copy —
two copies of this constant drifting apart is a known bug class, see
`.claude/rules/bug-class-checks.md` bug class 1.

## Current + redundant/

Every working-code directory holds **exactly one current file per
tool/module**. The moment a file is superseded by a newer version of the
same tool:

1. `git mv` the old file into a `redundant/` subfolder of that same
   directory.
2. Add the new file.
3. Do both in the **same commit**.

`redundant/` is where history lives — never delete a superseded file, and
never let two versions of the same tool sit side by side in the working
directory. If a file's supersession is worth explaining (why it changed,
what broke), record that in `CLAUDE.md` Section 3 or `.claude/docs/`, not
in the filename or a comment inside `redundant/`.

## Why this matters

A fresh session (or a fresh person) should be able to tell, at a glance and
without reading file contents, which version of anything is the one to
use — and still be able to find every prior version if history matters.
