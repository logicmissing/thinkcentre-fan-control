# Contributing

Read this file before you open a pull request. It states the expected
workflow for this project.

## 1. Before you start

- Read `CLAUDE.md` at the repo root. It states the current project status.
- Check open issues first. Do not duplicate an existing issue.
- For a large change, open an issue to discuss the change before you write
  code. This avoids wasted work.

## 2. Branch naming

Use this pattern:

```
<type>/<short-description>
```

Where `<type>` is one of: `feature`, `fix`, `docs`, `refactor`, `chore`.

Example: `fix/export-empty-file`

## 3. Commit messages

Write commit messages in the imperative mood. State what the commit does,
not what you did.

- Correct: "Fix empty CSV export on Windows"
- Incorrect: "Fixed a bug" or "Fixes"

Keep the first line under 72 characters. Add detail in the body if needed.

## 4. Code conventions

Follow `.claude/rules/coding-conventions.md`. In summary:

- Write comments and error messages for the actual audience of this
  project, not a generic developer audience.
- Use structured error handling, not ad hoc return-code checks.
- Verify claims about third-party APIs or libraries against a primary
  source before you rely on them.

## 5. File versioning

If your change replaces a working file (not a one-off doc), follow
`.claude/rules/versioning-and-archival.md`:

- Move the old file to `redundant/` in the same commit that adds the new
  one. Do not delete superseded files.
- Do not leave two versions of the same tool side by side in the working
  directory.

## 6. Pull requests

- Fill in every section of the pull request template.
- Link the issue your PR addresses.
- Keep the PR focused on one change. Open a separate PR for unrelated
  changes.
- Expect review comments. Respond to each comment before you ask for
  re-review.

## 7. Tests

If this project has a test suite:

- Add a test for each new behavior.
- Run the existing test suite before you open the PR.
- State your test results in the PR's test plan section.

If it does not, state in the PR how the change was checked by hand
instead.

## 8. Questions

If your question is about a defect or a proposed change, open a bug
report or feature request using the issue forms. Otherwise, contact the
maintainer directly — see `CODEOWNERS` for who that is.
