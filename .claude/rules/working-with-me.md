# Working with this project's operator

This rule exists so a fresh session picks up how the operator wants to
collaborate, without re-asking every time. See `.claude/docs/about-me.md`
for who they are; this file is about how sessions should behave.

## Check identity/config once, not every time

Before starting real work (not just answering a question) in a project
built from this template, check whether `.claude/docs/about-me.md` still
holds placeholder text instead of real answers. If it does, interview the
operator to fill it in before touching code — a handful of short
questions, not a long form. Once it's filled in, don't ask again; read it
instead.

This generalizes past identity: any other define-once fact discovered
during work (a real contact address, a real license choice, a real
default reviewer) gets written down where it belongs the first time it's
learned, not re-derived or re-asked on a later session.

## Scope the task before changing code

For any task that isn't a small, obvious fix: do the analysis first.
Identify the real options, weigh their tradeoffs, and present that to the
operator for a decision before writing the change — don't silently pick
one and present it as the only path.

## Keep scope minimal

Applied together with `coding-conventions.md`'s KISS/YAGNI/AHA section:
when in doubt about whether something is in scope, it isn't. Ask, don't
assume, when a task's boundary is unclear.

## Match engineering ceremony to the project's actual nature

The operator uses separate repos for disparate topics — a personal
market/product-analysis project and a work software-engineering project
never share one repo. `CLAUDE.md` Section 1 already states which kind a
given project is; nothing further needs to be asked.

If Section 1 describes a personal/analysis project rather than a
software-engineering one, apply the code-specific rules —
`versioning-and-archival.md`'s file-naming scheme,
`architecture-doc-guide.md`, `bug-class-checks.md` — only when actual
code is genuinely being produced. Don't impose them on a research note,
a spreadsheet, or a write-up just because they're always-loaded; being
loaded doesn't mean every rule applies to every deliverable.

## Boundaries specific to this repo

- **Never fill in `CLAUDE.md` Section 1 in this master template repo.**
  This repo (`General-Template`) is cloned to start each new project, and
  Section 1 is meant to be written once per generated project, not here.
  Confirmed with the operator: this template is only ever cloned for
  their own new projects, never handed to anyone else — so there is no
  "clear before publishing" step either. If that ever changes (the
  template gets shared or published), do a clear-out pass first: real
  content that has crept into the master (`.claude/docs/about-me.md`'s
  real identity fields, any project-specific notes in `reviewed-tools.md`)
  needs resetting to placeholder text before handoff.
- **Never edit a vendored skill's files directly** (anything under
  `.claude/skills/<name>/` sourced from an external repo per
  `.claude/docs/reviewed-tools.md`). If a vendored skill needs a change,
  make it upstream or note the needed change in `reviewed-tools.md`
  instead of silently patching the local copy — a silent local edit
  makes the vendored copy diverge from its logged source without a
  record of why.
