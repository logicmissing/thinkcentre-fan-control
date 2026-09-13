---
description: Check this project against the general-template repo it was generated from, and propose (never auto-apply) any upstream improvements to the tracked shared paths.
---

# /template-sync — pull reviewable updates from the source template

This project was generated from a template repo. Templates drift: a rule
file gets improved, a GitHub template gets a fix, months after this
project copied it. This command checks for that drift and proposes
catching up — it never overwrites anything on its own.

Prior art and design rationale: see the "/dream" and "/template-sync"
entries in `.claude/docs/reviewed-tools.md` — Copier's line-level
three-way-merge update mechanism was the reference point; this command
is a deliberately simpler, file-level version of the same idea (see "Why
file-level, not line-level" below), following the same propose-never-
overwrite non-negotiable as `/dream`.

## Non-negotiables

- **Propose, never overwrite.** Every change lands in a dated proposal
  file for the operator to review. Nothing is applied in the same turn
  it's found.
- **Never touch `never_sync` paths.** Even if a path is accidentally
  listed in both `synced_paths` and `never_sync` in the manifest, or the
  operator asks to sync one, `never_sync` wins — refuse and say why.
- **A local customization always outranks a silent overwrite.** If a
  synced file differs from the version this project was last synced at,
  that's a customization, not staleness. Flag it as a conflict for the
  operator to reconcile by hand — never guess which version should win.
- **No implicit path additions.** Only sync the paths actually listed in
  `.template-sync.yaml`'s `synced_paths`. If something outside that list
  looks like it should be kept in sync, say so as a suggestion, don't
  act on it.

## Why file-level, not line-level

Copier (a real project-scaffolding tool this pattern is loosely inspired
by) does a line-level three-way merge on update. This command does not —
it classifies each *whole file* as clean-apply, conflict, or no-op, and
leaves any real reconciliation to the operator. That's a deliberate
simplification: a coarser, easier-to-trust classification beats an
automatic line-level merge that could quietly combine two versions of a
file in a way nobody explicitly reviewed.

## Setup this command expects

A `.template-sync.yaml` at the project root:

```yaml
source_repo: <URL of the template repo this project was generated from>
source_ref: <commit SHA at generation time>
last_synced: <date of the last accepted sync>
synced_paths:
  - <path>
  - <path>
never_sync:
  - <path>
  - <path>
```

If this file doesn't exist, don't guess at its contents — ask the
operator for the source repo and, if known, the commit or approximate
date this project was generated, then create it before proceeding. If it
exists but `source_ref` or `last_synced` still hold placeholder text,
resolve those against the source repo's current state before doing
anything else, and tell the operator you did so.

## Procedure

1. **Fetch both ends.** Clone `source_repo` (or fetch if already cloned
   locally). Get the tree at `source_ref` (the baseline this project was
   last synced against) and at the source repo's current default-branch
   HEAD (the latest).
2. **Classify each file under each `synced_paths` entry:**
   - *Unchanged upstream* → no-op, skip.
   - *Changed upstream, and the local file is byte-identical to the
     `source_ref` version* → **clean-apply**: propose replacing it with
     the new upstream version.
   - *Changed upstream, and the local file differs from the `source_ref`
     version* → **conflict**: the operator customized this file. Show
     both diffs (local vs. baseline, and baseline vs. new upstream) side
     by side. Propose nothing automatic.
   - *Unchanged upstream, but local differs from baseline* → no-op (a
     local customization with nothing to reconcile against).
3. **Write the proposal** to
   `.claude/docs/template-sync-proposal-<yyyy_mm_dd_hh_mm_ss>.md`
   (timestamp per `.claude/rules/versioning-and-archival.md`), listing
   every clean-apply and every conflict with its diffs. Present it and
   stop.
4. **On operator acceptance:** apply only the accepted clean-apply items
   verbatim. For accepted conflict resolutions, apply exactly what the
   operator specified — don't infer a resolution yourself. Update
   `.template-sync.yaml`'s `source_ref` to the new upstream commit and
   `last_synced` to today, but only once every path is resolved; a path
   still in conflict blocks that update and should be called out in the
   proposal.

## What this does not do

- It does not run on a schedule or on session start — manual invocation
  only, so it never spends tokens without the operator asking.
- It does not sync anything not explicitly listed in `synced_paths`.
- It does not resolve conflicts for you.

## Retroactively adopting this template

The procedure above assumes `.template-sync.yaml` already exists — it
tells the difference between "the operator customized this" and "this
is just stale" by comparing against the commit the project was
generated from. A project that predates this template, or was never
generated from it, has no such baseline: every file at a template path
either doesn't exist yet, or was written independently and was never
derived from the template. That's not a sync — it's a one-time adoption
pass, and it needs a different procedure, run once, in the existing
project (not in the template repo itself):

1. **Inventory before touching anything.** List, for every path this
   template would add (`.github/`, `.claude/rules/`, `.claude/commands/`,
   `.claude/hooks/`, `CLAUDE.md`, `README.md`), whether the existing
   project already has something there. Just note present/missing —
   don't decide anything yet.
2. **Sort each into one of three buckets:**
   - *Missing entirely* → safe to copy in as-is. No conflict is possible
     if nothing existed there before.
   - *Present, and it's the project's own thing* (its own `README.md`,
     its own `CONTRIBUTING.md`) → needs a real read of both versions and
     a decision — keep it, replace it, or merge the useful parts in.
     This is a judgment call made once per file, never batched.
   - *Present, and clearly just a stub serving the same narrow purpose*
     (e.g. an empty `SECURITY.md`) → usually safe to replace, but still
     worth a quick look first.
3. **Add the no-conflict pieces first** — everything sorted as "missing
   entirely" in step 2. This is most of the work and none of it can
   clobber anything, since there was nothing there to clobber.
4. **Handle the overlapping files one at a time**, per the second
   bucket above. Don't batch these — a `CLAUDE.md` merge and a
   `CONTRIBUTING.md` merge are different decisions, and doing them
   together is how something gets silently dropped.
5. **Run the first-run interview** (`.claude/rules/working-with-me.md`)
   if this project has no `about-me.md` yet. Nothing new to invent —
   same interview, just run here too.
6. **Bootstrap `.template-sync.yaml` last, not first.** Once the
   adoption is done, create it with `source_ref` set to the *current*
   general-template commit — today becomes this project's generation
   point for sync purposes. From here on, the normal `/template-sync`
   procedure above applies, since there's now a real baseline to diff
   against.
7. **Commit in small, reviewable chunks** — per bucket, or even per
   file — not one large "adopt the template" commit. A bad call on one
   file should be easy to spot and revert without undoing the rest.
