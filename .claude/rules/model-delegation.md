# Model delegation: keep credit usage down

This project's operator has explicitly asked to keep credit/token usage
down (see `.claude/docs/about-me.md`). The rule below is the chosen
approach — evaluated against
[NVIDIA-NeMo/Switchyard](https://github.com/NVIDIA-NeMo/Switchyard), an
automatic model-routing proxy (Apache 2.0), and rejected for now because
it requires standing up and maintaining separate routing infrastructure,
which conflicts with this project's own KISS/YAGNI convention. Revisit
Switchyard if this project ever runs heavy automated API volume through
a harness it owns, outside interactive Claude Code sessions.

## The rule

The primary model does the planning and judgment calls: understanding
the task, deciding the approach, weighing tradeoffs, reviewing results.
A well-scoped subtask with little ambiguity — one where the instructions
can be fully specified up front — is a candidate for delegating to a
cheaper model instead of doing it at full price.

In practice, using the `Agent` tool: pass a cheaper `model` (e.g.
`"haiku"`) for a subtask that is narrow and mechanical, and leave the
default model for anything that requires judgment, or where getting it
wrong is expensive to redo.

## Cheap-model subtasks need clearer prompts, not shorter ones

A cheaper model needs the instructions to do more of the work that a
stronger model would otherwise infer. When delegating:

- State the exact scope, the exact files, and what "done" looks like —
  don't rely on it inferring intent.
- Give it a narrow, checkable success criterion, so a wrong result is
  easy to catch rather than silently accepted.
- If a delegated subtask's result looks wrong or incomplete, redo it with
  the primary model rather than retrying the cheap model repeatedly — a
  second failure costs more than the escalation would have.

## When not to delegate

Don't delegate: anything requiring the project's full context to get
right, anything where a wrong answer is expensive or hard to detect, and
anything genuinely small enough that the overhead of spinning up a
subagent isn't worth it. Delegating badly can cost more than not
delegating, once a redo is counted.

## Multi-agent formations (use only when one delegate isn't enough)

Reach for these only after the basic delegate-to-a-cheaper-model pattern
above stops being enough — most tasks never need them. Named here so
there's a shared vocabulary instead of re-inventing an ad hoc structure
each time, via [Cindy Zhu's guide to multi-agent Claude Code
setups](https://cindyzhu.com.au/guides/set-up-your-first-claude-agent-human-in-the-loop-starter-guide.html).
The "council" pattern from the same source is already covered by this
environment's own `llm-council` skill, so it's not repeated here.

- **Pipeline** — each agent's output feeds the next. Use for a fixed
  sequence of transforms.
- **Fan-out / fan-in** — several agents run in parallel on independent
  slices of the same problem, then their results merge. Use when the
  work is genuinely parallel, not sequential.
- **Orchestrator and workers** — one agent plans and delegates; workers
  execute narrow, well-scoped pieces. This is the pattern above, scaled
  to more than one worker.
- **Evaluator and optimizer** — one agent drafts, a second scores the
  draft against an explicit checklist, and they loop until it passes.
  Use when "good enough" needs an objective, checkable bar, not a
  subjective judgment call.
- **Debate** — agents critique each other's positions over rounds before
  a decision is made. Reserve this for a genuinely contested judgment
  call, not routine work — it's the most expensive pattern here.

Escalate deliberately: build the single-delegate case first, add an
evaluator/optimizer pair once "good enough" needs to be checked, and
never reach for debate or a full team unless the tradeoff is real.
Complexity here is a cost, not a default.

## Built-in commands that help

These ship with Claude Code itself — nothing to install, and worth
knowing before reaching for anything heavier above. The operator works
only on the web (see `.claude/docs/about-me.md`), so this list gives
each command's web status rather than assuming a terminal. Most were
checked against code.claude.com/docs/en/claude-code-on-the-web;
`/usage` and `/rewind` are undocumented there and were confirmed by
running them in a real web session instead.

- **`/compact`** — works in cloud sessions. Summarize the conversation
  to free up context without starting a new chat. Steerable with a note
  on what to keep.
- **`/context`** — works in cloud sessions. A live breakdown of what's
  filling the context window (history, files, tool output), so you can
  see bloat forming instead of just feeling the session get slower.
- **`/model`** — works in cloud sessions, but only if you pass the value
  as an argument, e.g. `/model sonnet`. It does not open a picker there.
- **`/rewind`** — works in cloud sessions. Not documented for the web;
  confirmed by running it, which lists the earlier prompts you can
  rewind to. Prefer it over typing "revert to the previous version" in
  plain English — that phrasing tends to make Claude guess at what you
  mean, burning tokens.
- **`/usage`** — works in cloud sessions. Not documented for the web;
  confirmed by running it. Shows current session cost and standing
  against plan limits.
- **`/clear`** — does NOT work in cloud sessions. Start a new session
  from the sidebar instead.
