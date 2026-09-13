# About the operator

This file answers "who am I working for, and how do they want to work,"
so a fresh session doesn't have to ask again. Filled in via a first-run
interview (see `.claude/rules/working-with-me.md` for the mechanism that
produced it, and for what to do if this file is ever reset to placeholder
text on a different project).

## Identity

- GitHub username: `logicmissing`
- Preferred address: no name preference — don't address by first name;
  plain "you" is fine.
- Security contact (used in `.github/SECURITY.md`): pangisaac9889@gmail.com

## Background

Chemical engineer, about 1 year of professional experience. Broad
knowledge of IT infrastructure. Not fluent in general-purpose programming
languages — hands-on coding experience is VBA and batch scripting.
Reviews every aspect of something carefully before deciding.

**What this means for how Claude should write for this audience:** keep
explanations simple. Don't assume familiarity with general
software-engineering jargon, frameworks, or ecosystems beyond VBA/batch
scripting unless it's explained first. This is the concrete case behind
the "write for the actual audience" rule in `coding-conventions.md`.

## Environment

- Timezone: Singapore, UTC+8 — confirmed correct, not assumed. Matches
  the constant already hardcoded in
  `.claude/rules/versioning-and-archival.md`.
- Working surface: the operator works exclusively in Claude Code on the
  web, not the local CLI. Every cloud session runs in a fresh, ephemeral
  container — the repo is cloned new at session start and the container
  is destroyed afterward. This means any gitignored file (runtime
  state, `.claude/settings.local.json` personal overrides) does NOT
  survive to the next session. General rule: any mechanism that needs
  to remember something between sessions must commit its state, or
  derive it from committed content instead.

## Licensing default

Projects built from this template ship with **no `LICENSE` file** by
default. Reasoning: much of this work involves proprietary or
confidential systems, not code meant for public release. No `LICENSE`
file means default copyright applies (all rights reserved) — nobody has
legal permission to reuse the code even if a copy leaks. That's a real
legal backstop, though it doesn't substitute for keeping the repo private
in the first place. A `LICENSE` file can be added to any project at any
time if it's later meant to be shared or open-sourced.

## Working style

- Do the analysis first. Weigh the pros and cons, then present the
  resulting options for a decision — don't present a decision already
  made as if there were no alternative.
- Strict scope discipline: KISS, YAGNI (no boilerplate, no placeholder
  structure for hypothetical future needs — solve only the problem
  asked), AHA / Rule of Three (duplication is fine up to two occurrences;
  only extract a shared helper once the same logic appears a third time).
  See `.claude/rules/coding-conventions.md`.
