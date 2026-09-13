# Loop engineering: running agents around a repo

An agent "loop" is: reason about what's next, act, check what happened,
repeat until done. This file distills the pattern from
[cobusgreyling/loop-engineering](https://github.com/cobusgreyling/loop-engineering)
(MIT) for running Claude semi-autonomously around a repo — daily triage,
PR babysitting, dependency sweeps — without losing control of it.

Four things worth telling apart, borrowing a framing from one "four
loops" description of the idea (an unverified talk transcript, not a
written source — treat this as a way to think about it, not a cited
fact): *what's next* (picking the move), *is it correct* (does it pass
tests/checks), *was it the right thing to build* (passing tests doesn't
mean it was worth shipping), and *is judgment improving* (learning from
past runs, not just running faster). Most tooling — this file included —
mainly covers the first two.

## The rollout ladder

Don't go straight to unattended. Roll out in stages, and don't advance a
stage until the previous one has been right for a while:

- **L1 — report only.** The loop runs, writes a report (e.g. `STATE.md`),
  and a human decides what to do about it. Nothing changes automatically.
- **L2 — assisted.** The loop proposes a specific change (e.g. in an
  isolated git worktree) but a human approves before it merges.
- **L3 — unattended.** The loop acts without a human in the per-run loop,
  inside an explicit allow-list of safe actions.

## Non-negotiables

- **State lives in a file, not memory.** A plain file (`STATE.md` or
  similar) records what the loop has seen and done, so a fresh session
  can pick up where the last one left off. That file must be **committed**,
  not just written to disk — the container is rebuilt every session, so
  an uncommitted file is gone. See `bug-class-checks.md` bug class 2.
- **An explicit allow/deny list gates any unattended action.** Never let
  a loop merge to main, touch credentials, or change security-relevant
  code without a human in the loop, whatever stage it's at.
- **A kill switch exists and is checked.** A label, flag, or file the
  loop checks before acting, so a human can stop it without editing its
  code.
- **Every run is logged**, in enough detail that a human (or a later
  session) can tell what the loop actually did, not just that it ran.

## When to use this

Worth adopting once a project has real, recurring janitorial work (issue
triage, dependency bumps, CI babysitting) — not worth the overhead
before that. Start at L1; most of the value comes from the report,
before any autonomy is added.

Given this project's stated preference for keeping credit usage down
(see `.claude/docs/about-me.md`), also see
`.claude/rules/model-delegation.md` — a loop's repeated, well-scoped
steps (e.g. "did this test pass, yes or no") are good candidates for a
cheaper model.
