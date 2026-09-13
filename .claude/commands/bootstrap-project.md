---
description: One-time first-run setup for a project generated from this template — fills in CLAUDE.md Section 1, runs the operator interview, clears the template's own build history, and prunes unused rules and skills. Propose and confirm before anything destructive.
---

# /bootstrap-project — first-run setup for a generated project

**Run this once, in a newly generated project — never in the master
template repo itself.** If the repo you're in is `General-Template`
itself, stop and say so; this command has nothing to do there.

This is a propose-then-confirm pass, same non-negotiable as `/dream` and
`/template-sync`: nothing destructive happens without the operator
confirming it first.

## Procedure

1. **Confirm this is a generated project.** Check the repo name / remote.
   If it's `General-Template`, stop immediately and say this command
   only runs in a project generated *from* the template, not in the
   template itself.

2. **Replace `.claude/hooks/session-start.sh`'s body** with this
   project's real setup (dependency install, etc.), or leave it as an
   orientation check if the project has no build step. It's listed in
   `.template-sync.yaml`'s `never_sync` for exactly this reason. Do this
   second, right after confirming step 1, because until it's replaced
   the session-start notice still points here rather than describing
   this project's own setup.

3. **Write `CLAUDE.md` Section 1.** It's deliberately blank in the
   template — this is the one place it gets filled in. Cover: what's
   being built, for whom, why, and anything about the working
   environment that changes how to operate. Also state which kind of
   project this is — personal/analysis vs. software engineering —
   because `.claude/rules/working-with-me.md` keys off that distinction
   to decide which rules actually apply.

4. **Set `PROJECT_TZ` in `.claude/project.env`** to the project owner's
   own IANA timezone name (default to the value already in the file if
   the owner is in the same place as before). This matters because both
   every generated filename's timestamp and the `/dream` staleness check
   read this one value.

5. **Run the first-run operator interview** if `.claude/docs/about-me.md`
   still holds placeholder text, per `.claude/rules/working-with-me.md`.
   If it's already filled in (carried over from the template), confirm
   it's still accurate for this project rather than re-interviewing.

6. **Delete the template's own build history**, which is meaningless in
   a generated project. List these by path and confirm before deleting:
   - `.claude/docs/backlog-review-checkpoint.md`
   - `.claude/docs/PR3_Audit_Report_2026_09_07_11_58_16.md`
   - `CLAUDE.md` Section 3.2 (the external-tool-review workstream)

   `.claude/docs/reviewed-tools.md` is KEPT — its verdicts stop the new
   project re-researching tools already decided on — but any line in it
   about this template's own construction can go.

7. **Fill in `.template-sync.yaml`'s `source_ref`** (the template's
   commit SHA at generation time) **and `last_synced`** (today).

8. **Walk the operator through the `.github/` defaults, one at a time,
   and ask accept or decline for each.** Read the real file for each
   item — don't assume — and show the operator its current value:
   - the owner line in `.github/CODEOWNERS`
   - the supported-versions table, the reporting contact, and the
     response-process section in `.github/SECURITY.md`
   - the reporting contact in `.github/CODE_OF_CONDUCT.md`
   - which `package-ecosystem` blocks are active in
     `.github/dependabot.yml`

   Only edit a file when the operator declines a value and says what it
   should be instead. This distinction matters for `/template-sync`
   later: a default the operator accepts is left byte-identical to the
   template, so `/template-sync` sees no difference and never reports
   it; a default the operator declines and edits is a real
   customisation, so `/template-sync` will correctly flag it as a
   conflict later — that is the intended behaviour, not a nuisance.

9. **Rewrite `README.md` for this project:** replace `<Project Name>`,
   the one-line description, and the Contents list, and delete the
   "Using this template" section — it only applies to the template repo.

10. **Prune rules that don't apply.** Every file in `.claude/rules/`
    loads into context in EVERY session — roughly 7,500 tokens across the
    13 files this template ships. Deleting the ones this project will
    never use is a real, recurring saving, not tidiness. On a project
    that is neither Excel nor process engineering, the usual candidates
    are `excel-conventions.md` and
    `process-engineering-conventions.md`.
    Alternative to deleting: add `paths:` frontmatter to a rule so it
    loads only when Claude touches matching files — but a path-scoped
    rule will NOT load when Claude is authoring the *first* file of that
    type, so deleting is safer for a rule the project genuinely never
    needs.

11. **Same question for `.claude/skills/`.** The vendored skills cost
    roughly 4,900 tokens of description in every session. Deleting a
    skill set the project will never use (e.g. the chemical/process
    engineering sets on a non-engineering project) is the single largest
    available saving. They can be restored later from the source repos
    listed in `.claude/docs/reviewed-tools.md`.

12. **Commit the bootstrap as its own commit**, so a bad call is easy to
    revert.

## What this does not do

- It does not run on a schedule.
- It does not delete anything without confirming first.
- It runs once. Ongoing template updates are `/template-sync`'s job, not
  this command's.
