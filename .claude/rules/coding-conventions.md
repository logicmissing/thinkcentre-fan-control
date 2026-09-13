# Coding conventions

These are general working conventions. Add a language- or framework-specific
rule file alongside this one (e.g. `python-conventions.md`,
`vba-conventions.md`) when a project needs concrete syntax-level rules —
keep this file for the conventions that hold regardless of language.

## Write for the actual audience

Comments, error messages, and doc prose should be written for the person
who will actually read them — not assumed to be a fellow programmer unless
that's true. If the project's owner is a domain expert who isn't a
developer, error messages should say what went wrong in their terms, and
comments should explain domain reasoning, not restate code.

## Structured error handling

Use whatever the language's structured-error-handling idiom is, applied
consistently — a `try/catch` equivalent, not ad hoc return-code checking
mixed with exceptions. Small, focused procedures/functions; clear naming
over clever naming.

## Keep scope minimal

- **KISS.** Prefer the simplest design that solves the actual problem.
- **YAGNI** ("You Aren't Gonna Need It"). Don't write boilerplate,
  placeholders, or structure for hypothetical future expansion. Solve
  only the problem actually requested.
- **AHA (Avoid Hasty Abstractions) and the Rule of Three.** Duplicating
  logic twice is fine. Extract a shared helper or component only once
  the exact same logic appears a third time — not before, on the guess
  that it might be reused.

## Verification-first habit

Every non-trivial claim about how a third-party system, API, or library
behaves should be checked against a primary source before it's written
into code or documentation:

- A real spec, decompiled type library, or official reference — not
  general/forum knowledge about "similar" products, which can describe a
  related-but-different thing and be confidently wrong.
- Real extracted source from an existing working example, if one exists.
- A live test result reported back by whoever can actually run the code,
  when no other ground truth is available.

When this habit catches a wrong assumption, record it in `CLAUDE.md` or
`.claude/docs/` so the correction isn't silently lost or re-derived later.
See `CLAUDE.md` Section 4 for where this project's ground-truth sources
live.

## Done means it ran, not that it reads correctly

A change to anything runnable — a script, a hook, a macro, a query —
is not finished when it looks correct. It is finished once it has
actually been run.

Run it against its failure cases, not just the case it was written
for: the missing file, the empty value, the wrong value, the
boundary case, and the input that should produce nothing at all.

Show the actual output. A statement that "it works" is not evidence;
the pasted output is the evidence.

If it genuinely cannot be run in the current environment, say so
plainly, name exactly what someone else has to run to close the gap,
and report the change as unverified — never as done.

Reading the code only proves the code says what you meant. Running
it proves it does what you meant. See `.claude/rules/bug-class-checks.md`:
both of its recorded bug classes read correctly and were silently
wrong until they were actually run.
