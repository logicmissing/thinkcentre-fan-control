# Architecture documentation guide

Use this when a project needs an `ARCHITECTURE.md` (or a filled-in
`.claude/docs/architecture.md`) that describes how the system fits
together. The point is not to describe every line of code — it's to make
architectural intent explicit instead of leaving Claude to infer it from
a file tree.

Answer these six questions. Keep each one short — a diagram or a few
lines, not a page.

1. **What exists?** The high-level system map (e.g. `Client -> API ->
   Services -> Database`).
2. **Who owns what?** Which component owns each responsibility (e.g.
   `Auth -> identity + sessions`, `Billing -> subscriptions +
   entitlements`).
3. **What may depend on what?** The allowed direction of dependencies
   (e.g. `UI -> Application -> Domain -> Infrastructure`), and explicitly
   named forbidden paths (e.g. "UI must never call the Database
   directly").
4. **How does data move?** The critical flows, end to end (e.g. `User
   action -> UI -> Service -> Repository -> DB -> State refresh`).
5. **What must stay true?** The invariants that must never be violated —
   e.g. secrets stay server-side, each piece of domain logic has exactly
   one owner, boundaries aren't bypassed, new architectural patterns
   aren't introduced silently.
6. **When should Claude stop?** If a task would require breaking an
   architectural boundary: stop, explain the conflict, show the impact,
   and propose the smallest change that doesn't break it — don't just
   route around the boundary.

A file tree says where the code is. This document says how the system is
*supposed* to fit together — a project needs both.

Two external tools can help keep this doc accurate on a real codebase by
generating a queryable map of it — see the "Architecture / code-graph
tools" entry in `.claude/docs/reviewed-tools.md`. Neither is required;
this six-question doc works fine written by hand.
