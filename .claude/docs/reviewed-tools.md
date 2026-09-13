# External tools and patterns reviewed

**Where this file came from, and what it does and does not describe.**
This log was copied whole from the `General-Template` scaffold (commit
`d67355a`) when this project took on that scaffold. It is kept for its
*verdicts* — so a session here does not re-research a tool already
checked, or re-propose one already rejected for a stated reason.

Two things to keep straight while reading it:

- The **"Vendored into this repo" table below describes the template, not
  this repo.** None of those skill sets were brought into
  thinkcentre-fan-control — they are pump, fluids and process-engineering
  skills, and this is a Windows C# utility. See `CLAUDE.md` Section 6.
  The table is still the right place to look if one of them is ever
  wanted here: it records each source repo and license.
- Entries written in the first person about "this template's" own
  construction are the template's history, not this project's.

New verdicts reached while working on *this* project belong here too —
add them the same way, one row per item, with the reason.

---


A running record of every external repo, tool, or pattern considered for
addition to this template, so a fresh session doesn't re-research
something already checked, and doesn't re-propose something already
rejected for a stated reason. Verified by cloning and reading the actual
repo (license, last commit, README), not by search-result summaries
alone, unless noted otherwise.

Update this file the same way it's structured: one row per item,
verdict, and why. Don't delete rejected entries — a "not now" from six
months ago is exactly the kind of thing worth not re-litigating.

## Corrections to this file's own methodology

- **`Soljourner/claude-engineering-skills` was originally rejected as a
  "domain mismatch" based on the repo's own README self-description
  ("mechanical/aerospace/pump engineering") and a WebFetch summary —
  never actually cloned or read at the skill-file level.** The operator
  caught this: the repo contains a dedicated `coolprop-db` skill and a
  `nist-refprop` skill (CoolProp is a real, MIT-adjacent open-source
  thermophysical property library, validated against NIST REFPROP —
  directly relevant to chemical engineering, not mechanical/aerospace),
  plus `thermo-package`, `thermodynamics`, `fluid-dynamics`, and
  `pump-design/cavitation-analysis` skills. Corrected after actually
  cloning the repo and reading the real skill files — now vendored in
  full (see the "Vendored" table above). **Lesson applied going
  forward: verify by reading actual file content, not a repo's own
  top-level self-description or a summary fetch — a project's README
  headline can foreground one audience (here, mechanical/CAD users)
  while genuinely serving a different one too.**
- A systematic re-check of every other entry in this file against that
  same standard (actual file content, not summary) is in progress as of
  this note — see the operator's request in conversation. Entries
  updated as a result of that pass will note it explicitly, the same
  way this one does.
- **Verified against the official Claude Code docs this session**
  (code.claude.com/docs/en/memory): `.claude/rules/*.md` files ARE
  discovered recursively, and rules without `paths:` frontmatter load at
  launch with the same priority as `CLAUDE.md`. This corrected a wrong
  claim in `excel-conventions.md`'s header (that a subfolder under
  `.claude/rules/` "is not reliably auto-loaded") and a matching bug in
  `session-start.sh` (`-maxdepth 1` on its rule-counting `find` calls,
  which under-reported rules in subdirectories).
- **Verified against the official Claude Code docs this session**
  (code.claude.com/docs/en/hooks): `Stop`-hook stdout is never shown to
  the operator or to Claude — it goes to the debug log only. Only
  `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and
  `PostModelSwitch` have their stdout added as visible context. This
  meant `dream-check.sh` (a Stop hook) never actually surfaced its
  staleness reminder; it's now a SessionStart hook instead.
- **Found this session:** even after the Stop-to-SessionStart fix above,
  `dream-check.sh` still couldn't work for this operator — it kept its
  staleness clock in a gitignored runtime-state file, and the operator
  works exclusively in ephemeral cloud containers where a
  gitignored file never survives to the next session. The clock could
  never advance, so the reminder could never fire. Resolved by dropping
  the state file entirely: the clock is now derived from the newest
  committed `dream-proposal-*.md` filename, falling back to the repo's
  first-commit date when no /dream pass has run yet.

## Vendored into this repo

| Item | License | Where it lives |
|---|---|---|
| [RinDig/icm-architect](https://github.com/RinDig/icm-architect) — "ICM": folder structure as agent architecture, a general-purpose methodology for structuring any AI-agent-driven workspace | MIT | `.claude/skills/icm-architect/` (SKILL.md, assets/, references/, LICENSE copied alongside). Content is markdown only, no executable code. |
| [Soljourner/claude-engineering-skills](https://github.com/Soljourner/claude-engineering-skills) — 20 engineering skills across databases, packages, integrations, helpers, and "thinking" workflows | MIT | `.claude/skills/claude-engineering-skills/` (full repo: `skills/`, `docs/`, README, LICENSE — `__pycache__` build artifacts excluded). **Verdict corrected from an earlier pass** (see "Corrections" below) — vendored in full at the operator's request, including the CAD/mechanical-specific skills (SolidWorks, ANSYS, COMSOL, OpenFOAM), for personal 3D-printing use rather than only the chemical-engineering-relevant subset. Last commit 2025-11-07 (~10 months stale) — less of a concern for reference-data skills (fluid/material properties don't change) than for pinned package versions. |
| [jskherman/engg-skills](https://github.com/jskherman/engg-skills) — 32 agent skills for chemical/process engineering, applied sciences, and engineering statistics (distillation, heat-exchanger sizing, material/energy balances, relief-valve sizing to API 520, control-valve sizing to ISA 75.01.01, separator sizing, reactor sizing, amine treating, SPC/DOE) | Apache-2.0 (confirmed in the repo's own LICENSE file; all bundled dependencies — Caleb Bell's `thermo`/`chemicals`/`fluids`/`ht`, PyMC, ArviZ, NumPy/SciPy/pandas — are MIT/Apache-2.0/BSD) | `.claude/skills/engg-skills/` — **31 of 32 skills vendored; `literature-search-engineering` deliberately excluded.** Verified by cloning and reading actual files, not a summary. Directly fills the gap noted in `CLAUDE.md` Section 3.2 (the previously vendored skill set is fluids/pump/mechanical-heavy, with nothing for distillation, heat exchangers, mass balances, or process-safety sizing). The repo's own `NOTICE.md`/`SKILL_LICENSES.md` independently state the same discipline this template's `process-engineering-conventions.md` asks for: name the standard, don't reproduce proprietary standard text, state the calculation doesn't replace qualified engineering judgment. Minor disclosed-and-accepted risk: `reactor-sizing-and-kinetics/scripts/reactor.py` evaluates a user-supplied rate-law expression through a restricted `eval()` (`__builtins__` stripped) — a locally-invoked CLI convenience, not treated as blocking. **Why `literature-search-engineering` was excluded:** its scripts (`download_doi_pdf.py`, `resolve_open_access_pdf.py`) shell out via `uvx --from git+https://github.com/Oxidane-bot/scihub-cli.git` to fetch and run a third-party tool at an unpinned git ref, and hard-code Sci-Hub and LibGen mirror fallbacks (`LIBGEN_MIRRORS = ("vg", "gl", "la", "bz")`) — a real supply-chain-execution risk (unpinned third-party code runs on every invocation) and a legal/access-control-bypass concern, and it directly **contradicts** that same repo's own `SKILL_LICENSES.md`, which claims "the skill refuses Sci-Hub/LibGen-style access-control bypass workflows." Flagging the doc/code mismatch here in case it matters for anything else pulled from this repo later. Not needed for this operator's actual use case (engineering calculations, not literature retrieval) — excluded rather than patched, to keep the vendored copy matching upstream. |

## Distilled into this repo's own rules (not copied verbatim)

| Item | License | Where it landed |
|---|---|---|
| [cobusgreyling/loop-engineering](https://github.com/cobusgreyling/loop-engineering) — pattern library for running agents around a repo (daily triage, PR babysitting, CI sweeps), L1→L2→L3 rollout ladder | MIT | `.claude/rules/loop-engineering.md` |
| Karpathy's LLM Council methodology (multi-model query → anonymized peer review → chairman synthesis) | [karpathy/llm-council](https://github.com/karpathy/llm-council) has **no LICENSE file** — not copied. The pattern itself is already implemented natively as this environment's own `llm-council` skill. | Attribution note in `CLAUDE.md` Section 6 |
| Architecture "6 questions" framework (what exists / who owns what / dependency direction / data flow / invariants / when to stop) | Given directly by the operator, not sourced from an external repo | `.claude/rules/architecture-doc-guide.md` |
| Anti-hallucination + token-efficiency behavior specs | Given directly by the operator | Merged into `.claude/rules/response-style.md` |
| "Four loops" framing (what's next / is it correct / was it worth building / is judgment improving) | An unverified talk transcript, not a written source — treated as a framing device, not a citable fact | Noted inside `.claude/rules/loop-engineering.md` |
| Reasoning trigger words (first principles, premortem, steelman, falsify, second order, base rates, inversion, 80/20, socratic, next step) | Given directly by the operator | `.claude/rules/reasoning-triggers.md` |
| Fable-as-planner / cheap-model-delegation idea | Given directly by the operator; evaluated against NVIDIA-NeMo/Switchyard (see below) | `.claude/rules/model-delegation.md` |
| Personal-vs-work project classification | Given directly by the operator; resolved as "use separate repos per topic," so no new interview question or file was needed — just a connective rule | `.claude/rules/working-with-me.md` ("Match engineering ceremony to the project's actual nature") |
| `CLAUDE.md` size budget (~200 lines / ~2,000 tokens) | Two independent secondary sources converged on this: Cindy Zhu's guide says ~200 lines, Mika Reyes' "How to Setup Global Context for Claude" says ~2,000 tokens, both citing the same reason (a bloated always-loaded file degrades instruction-following). Neither fetched as a primary source in this session — both via a second Claude session's summary, pasted by the operator. | `CLAUDE.md`'s own header, plus a short note on how it layers under `about-me.md` (also from Mika Reyes' guide: global → project → subfolder, most specific wins) |
| Multi-agent "formations" vocabulary (pipeline, fan-out/fan-in, orchestrator-and-workers, evaluator-and-optimizer, debate) | [Cindy Zhu's multi-agent guide](https://cindyzhu.com.au/guides/set-up-your-first-claude-agent-human-in-the-loop-starter-guide.html), via the same second-session summary. Its "council" pattern is not repeated — already covered by this environment's own `llm-council` skill, per the operator. | `.claude/rules/model-delegation.md` ("Multi-agent formations") |
| Confidence rating (High/Medium/Low) per `/dream` finding | Mika Reyes' "How to Keep Your CLAUDE.md From Going Stale (Context Updater)" guide — her version rates each proposed change this way; ours didn't. Her guide also uses MCP connectors (Calendar/Slack/Gmail) as an additional signal source beyond session transcripts — not adopted here, since this template can't assume any project has connectors configured; worth revisiting per-project if one does. | `.claude/commands/dream.md` (PROPOSE step + Output section) |
| Built-in Claude Code cost-management commands (`/usage`, `/context`, `/model`, `/rewind`, `/compact`) | Mika Reyes' "5 Claude Code Commands to Stop Burning Money on Tokens." These are native commands, not third-party tools — nothing to vendor, just a reference. Names not verified against current Claude Code docs directly this session. | `.claude/rules/model-delegation.md` ("Built-in commands that help") |

## Link only — good tools, not vendored, and why

| Item | License | Why not vendored |
|---|---|---|
| [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — 356 Claude Code subagent definitions (`.claude/agents/` format) across ~20 professional domains (engineering, marketing, sales, finance, healthcare, security, etc.) | MIT | Explicitly built to run separately — its own multi-tool installer (`scripts/install.sh --tool claude-code`, installs to the *global* `~/.claude/agents/`, not a project) and a standalone desktop app (agencyagents.app), not a `/plugin install` marketplace entry. Subagent files are lazy-loaded by Claude Code's own design (name/description in routing metadata, full body only on dispatch — moderate confidence, not verified against primary docs this session), so token cost isn't the blocker; scale and domain mismatch are. None of its ~20 domains (SaaS-shop roles: engineering, marketing, sales) obviously fit this operator's actual profile (chemical engineering, VBA/batch — see `about-me.md`). Install selectively and directly (`./scripts/install.sh --division <name>` or `cp <division>/*.md ~/.claude/agents/`) if a specific persona is ever wanted — nothing to do in this repo for that. |
| [obra/superpowers](https://github.com/obra/superpowers) — full agentic dev methodology plugin (brainstorm → worktree → plan → TDD → review → merge) | MIT | Distributed as a Claude Code **plugin**; install, don't copy. See README for install steps. |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — 9 slash commands mapped to the dev lifecycle (`/spec` → `/ship`) | MIT | Same reasoning — install as a plugin, alternative/complement to Superpowers. See README for install steps. |
| [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail) — actively discourages AI over-building (benchmarked ~54% less code) | MIT | Its philosophy already exists in `coding-conventions.md`'s KISS/YAGNI section; the tool is a live enforcement plugin, not template text. |
| [rtk-ai/rtk](https://github.com/rtk-ai/rtk) — Rust CLI that compresses shell command output before it reaches an agent's context | Apache 2.0 | External binary tool, not something to vendor into a docs repo. Relevant to token-usage concerns; worth trying directly if context bloat from tool output becomes a problem. |
| [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) — maps a codebase into a queryable knowledge graph via tree-sitter | Apache 2.0 / MIT dual | SaaS-backed CLI (YC-backed startup). Relevant companion to `architecture-doc-guide.md` if a project wants an automatically generated system map. |
| [Egonex-AI/Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) — same category as Graphify, broader agent-CLI compatibility | MIT | Alternative to Graphify; pick one if wanted, not both. |
| `Leonxlnx/taste-skill` (aka "Taste Skill" / tasteskill.dev, includes the "image-to-code" skill — these are all the same repo, not three different things) | MIT | Real, small skill bundle. Lower priority than ICM; optional vendor later if UI/frontend work becomes a recurring need. |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (web-design-guidelines skill) | **No LICENSE file** | Cannot vendor — no license means default all-rights-reserved. Install via Vercel's own `npx skills add` instead. |
| [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) — 73 "DESIGN.md" files extracted from real companies' actual websites | MIT (repo) | Flag: even under MIT, copying one company's extracted design tokens into a generic template risks brand/trademark issues regardless of the repo's own license. Link only; never vendor a specific company's file. |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — 192 UI/UX reasoning rules | MIT | Real but large and donation-driven; better as an optional install than vendored wholesale. |
| [nidhinjs/prompt-master](https://github.com/nidhinjs/prompt-master) — small prompt-optimizing skill | MIT | Small, easy vendor if wanted, but a marketing-heavy README and lower signal than the others reviewed. Optional. |
| [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli) — official Playwright browser-automation CLI + Claude Code skill | Apache 2.0 | Good, small, official, easy to add on request — but browser automation isn't a universal need for every project from this template. Not vendored by default (YAGNI); pull in `skills/playwright-cli/` from the source repo when a project actually needs it. |
| "Playwright Plugin \| Claude by Anthropic" | Apache 2.0 | Confirmed by the operator to be the same item as `microsoft/playwright-cli` above, not a separate tool. Verdict unchanged: good, official, not vendored by default (YAGNI). |
| [Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts) — reverse-engineered archive of Claude Code's own system prompts across versions | MIT | Research curiosity, not a template feature. Updated within minutes of each Claude Code release. |
| [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) — broad best-practices collection covering subagents, commands, skills, hooks, MCP, memory | MIT | Explicitly "constantly updated" (commits same-day as review). Link and re-check live; don't snapshot into this repo. |
| [reporails/rules](https://github.com/reporails/rules) — a validator/linter specifically for agent instruction files (`CLAUDE.md`, `.cursorrules`, etc.) | **CC BY-SA 4.0 (ShareAlike)** | Directly relevant to this exact repo. Copyleft license means any of its rule *content* copied in would obligate this repo (and downstream projects) to the same license — don't vendor. Safe to use as an external check instead: `npx @reporails/cli check` against this repo's own `CLAUDE.md`/`.claude/rules/`, since running a tool against the repo doesn't copy its content into it. |
| [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) — static + LLM-assisted security scanner for third-party agent skills (prompt injection, exfiltration, supply-chain risk) | Apache 2.0 | Genuinely useful practice for vendoring future third-party skills. Not run against ICM this round — ICM's vendored files were manually confirmed to be markdown-only with no executable code. Worth running on anything heavier before vendoring it. |
| [NVIDIA-NeMo/Switchyard](https://github.com/NVIDIA-NeMo/Switchyard) — automatic per-call model-routing proxy, routes to the cheapest model that can do the job | Apache 2.0 | Pre-1.0, standalone proxy explicitly "not for production" per its own docs. Requires standing up and maintaining routing infrastructure — rejected in favor of the manual approach in `model-delegation.md`, which needs no new infrastructure. Revisit only if this project starts running heavy automated API volume through its own harness. |
| [affaan-m/ECC](https://github.com/affaan-m/ECC) | MIT | The operator's own existing install, not a candidate for this template. A reported UI bug (skill triggers don't show a status bubble) belongs in that project's own issue tracker, not here. |

## Link bundles (curated lists, not individually verified beyond confirming they exist)

| List | License | Note |
|---|---|---|
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | **CC BY-NC-ND 4.0 (No-Derivatives)** | Cannot copy any of its content — link only, ever. Its own resource table also surfaced three items worth naming directly: **anthropics/claude-code-security-review** (confirmed via its own README: it's the official source of Claude Code's built-in `/security-review` slash command — this session's `security-review` skill already is this tool, nothing further to add), the official **Ralph Wiggum** orchestration-pattern plugin, and **activeloopai/hivemind** (memory/context persistence — related to `/dream`, which has since been built; see below). |
| [webfuse-com/awesome-claude](https://github.com/webfuse-com/awesome-claude) | **CC0 (public domain)** | Unlike the list above, genuinely unrestricted. Also a hub pointing to further lists: `travisvn/awesome-claude-skills`, `BehiSecc/awesome-claude-skills`, `langgptai/awesome-claude-prompts`, `vijaythecoder/awesome-claude-agents`, `VoltAgent/awesome-claude-code-subagents` — not individually verified. |

**Dead end, don't re-try:** Cindy Zhu's site (cindyzhu.com.au) claims a
"90+ guides" library, but the index page is JavaScript-rendered with no
static content to fetch. A sitemap.xml, a `site:cindyzhu.com.au` search,
and targeted phrase searches (resume, content engine, hooks, slash
commands, brand voice, DESIGN.md, Instagram link-in-bio) all came up
empty beyond the 6 guide URLs already logged above. Two guides are
teased on her homepage ("4 Claude skills that make your resume
unrejectable," "free content engine: 3 tools + Claude as the brain") but
no standalone URL was found for either — possibly not indexed, or a
slug pattern not yet tried.

## Evaluated in depth and rejected

- **[juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)** — a
  Claude Code plugin that switches response style to a deliberately
  terse, dropped-grammar "caveman" mode to cut output tokens. Surfaced
  via Mika Reyes' review (a second Claude session's summary, not fetched
  directly). Verified by cloning:
  - **License is split, not a single MIT grant.** `LICENSING.md` states
    the `skills/` directory (including the core `caveman` skill itself)
    is MIT, but the actual compression engine, proxy, rewriter, and
    browser-automation core (`engine/`, `proxy/`, `rewriter/`, `browse/`,
    `mcp/`, `shrink/`) are **BSL-1.1**, which requires a commercial
    license for third-party hosted/managed/embedded use. The skill and
    the engine are licensed differently on purpose.
  - **It's a large ecosystem, not a single skill.** The repo ships 19+
    sub-skills (`caveman-commit`, `cavecrew`, `caveman-compress`,
    `caveman-review`, etc.), a Go compression core, a browser driver, and
    an MCP server — considerably more than "a skill that makes responses
    terser."
  - **The token-savings figure is inconsistent between sources.** The
    plugin's own `plugin.json` claims "cuts 65% of output tokens against
    an unprompted baseline (measured)" — its own self-reported number.
    The secondary summary that surfaced it said "~75%." Neither figure
    is independently verified here; the discrepancy itself is a reason
    for caution about the claim.
  - **Rejected for use in this template, on a direct comparison against
    `response-style.md`'s Simplified Technical English (STE) grounding**
    (the operator's own explicit request for this comparison): caveman
    mode and STE optimize for opposite things. Caveman mode's own
    `SKILL.md` instructs "respond terse... only fluff die" — it drops
    articles, connectives, and explicit reasoning steps, on the
    assumption the reader can reconstruct meaning from a compressed
    signal. STE optimizes for the opposite: unambiguous comprehension by
    a reader without deep domain background, even when that costs more
    words — which is exactly what `about-me.md` says this operator
    needs (a chemical engineer, not a general-purpose programmer).
    Applying caveman-style compression to operator-facing output would
    work directly against the reason `about-me.md` and
    `response-style.md` exist. The tool's own README demonstrates this
    tension unintentionally — it's written in caveman-speak throughout
    ("why use many token when few do trick"), which is memorable but
    measurably harder to parse at a glance than plain English.
  - **Not entirely without merit, just not for this use.** The
    compression idea could be legitimate for internal, agent-to-agent
    exchanges a human never reads directly (e.g. a `/dream` FAN OUT
    digest) — a human-facing/machine-facing style split, not a single
    global mode. Not built now: nothing in this template currently
    produces that kind of internal-only digest at a volume where it
    would matter (YAGNI). Revisit only if that changes.

## Built as a new template pattern (not vendored from any single source)

- **`/dream` memory-consolidation command** — the operator's pasted spec (digest → fan out → cluster → verify → propose → apply) didn't match one single known source, but two real reference points corroborated the same concept and shaped the final design:
  - **Anthropic's own "Dreaming" feature** for **Claude Managed Agents** (a distinct product from Claude Code, currently research-preview/access-request-only) — reported via multiple independent secondary sources (blog writeups, not Anthropic's own docs) as three phases (orient → consolidate → output-as-reviewable-diff), trigger = 24h elapsed OR 5 sessions accumulated, plus a manual `/dream` override. A vendor-reported "~6x task completion" figure for one customer (Harvey) is an internal Anthropic metric, not independently verified.
  - **[coder/xum#3534](https://github.com/coder/xum/issues/3534)** — a feature-request issue for the same concept in a different tool ("Mux"). Contributed the **operation budget** (max 8 changes/pass), **net-shrink validation** (a pass must not grow total memory size), and **pin protection** (operator-marked content a pass may never touch) guards that the final implementation uses.
  - Community Claude Code implementations of the general idea also exist: `jl-cmd/claude-dream`, `timoncool/dream-skill`, `grandamenium/dream-skill` (not used as a direct source).
  - **Implementation:** `.claude/hooks/dream-check.sh` (a Stop hook — zero-LLM-cost staleness reminder only, never runs the pipeline itself) plus `.claude/commands/dream.md` (the actual pipeline, invoked manually). Not enabled by default in every project instantiated from this template beyond being present in the scaffold — same reasoning as `loop-engineering.md`: worth having available, not worth forcing on a project with no session history yet to consolidate.
  - **Diverged from Anthropic's trigger since the above was written:** this repo's hook reminds only once a first `/dream` pass has produced a committed proposal file (never nagging a project that hasn't opted in), and gates on elapsed days AND commits since that pass, not a session count. A session count can't be kept here — the operator's containers are ephemeral, so the gate is derived from committed content (the proposal filename, git log) instead.

- **`/template-sync` command** — the operator's own idea: since generated projects are normally static copies of this template, could a project pull in later improvements to the template without risking overwriting its own developed work? Loosely inspired by **Copier** (a real Python project-scaffolding tool, verified via its own docs) — Copier does a line-level three-way merge on update. This implementation is deliberately simpler: a file-level classifier (clean-apply / conflict / no-op) rather than a line-level auto-merge, on the same propose-never-overwrite non-negotiable as `/dream`.
  - **Implementation:** `.template-sync.yaml` at the project root (tracks the source repo, the commit a project was generated from, and which paths — `.github/`, `.claude/rules/`, `.claude/commands/`, `.claude/hooks/` — stay in sync; `CLAUDE.md`, `README.md`, `about-me.md`, `architecture.md`, and `.claude/skills/` are explicitly excluded) plus `.claude/commands/template-sync.md` (the diff-and-propose procedure, invoked manually).
  - `.claude/commands/template-sync.md` also documents a separate **retroactive-adoption procedure** for a project that predates this template (no `.template-sync.yaml`, no shared baseline to diff against) — a one-time inventory-and-adopt pass rather than an ongoing sync, ending with bootstrapping `.template-sync.yaml` against the current commit so normal syncing works from then on.
  - Approved for a full build by the operator; deliberately held until PR2 (the previous round of work) merged, to avoid moving the target mid-review.
  - Not yet exercised end-to-end — no downstream project has run a real sync (or a retroactive adoption) against this repo yet.

## TODO — candidates pending a build decision

Verified and discussed, not yet built. Listed here so a fresh session
doesn't re-research any of them from scratch.

- **Level 3 semantic search (memory taxonomy from a MindStudio article
  the operator uploaded, "Claude Code Memory Levels Explained: 6 Layers
  from claude.md to Cross-Tool Shared Memory")** — this repo currently
  implements Level 1 (`CLAUDE.md`/`.claude/rules/`) and something
  Level-2-adjacent (`dream-check.sh`, a session-lifecycle hook), but
  nothing at Level 3 (semantic search over past sessions), 4 (verbatim
  recall), or 6 (cross-tool shared memory). Two Level 3 tools verified
  by cloning:
  - **[zilliztech/memsearch](https://github.com/zilliztech/memsearch)**
    — MIT, very active, installs via Claude Code's own plugin
    marketplace (`/plugin install memsearch`). Markdown files are the
    real source of truth; the vector index (a local, embedded "Milvus
    Lite," not a cloud service) is an explicitly disposable, rebuildable
    "shadow index." Leading candidate.
  - **[thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)**
    — Apache 2.0, active, but its own README states it has rebranded to
    "Grok Mem" and now targets "how Grok Bots remember" — Claude Code
    support continues under the old package name, but the project's
    direction is less predictable post-rebrand. Not recommended over
    memsearch.
  - Found but not deep-verified: `zelinewang/claudemem`,
    `christian-byrne/claude-code-vector-memory`, `kunickiaj/codemem`,
    `supermemoryai/claude-supermemory`, `yoloshii/ClawMem`.
- **Level 6 (cross-tool shared memory)** — confirmed this requires
  infrastructure genuinely separate from any git-tracked template
  content: a runtime database, not a repo file. The article's own
  reference implementation (a builder's SQLite-based "hive mind") is
  explicitly local-only, matching memsearch's own local-first default —
  the operator's instinct to keep this private is already how these
  tools default to working. The operator's Google Drive/OneDrive-sync
  idea is workable in principle (memsearch's real storage is plain
  files), with one caveat: file-sync tools aren't transactional, so two
  sessions writing to the same synced file at once risks a conflict —
  markdown files (memsearch's model) tolerate this better than a single
  SQLite file would.
- **[github/spec-kit](https://github.com/github/spec-kit)** — GitHub's
  own official Spec-Driven Development toolkit, MIT, just reached
  v1.0.0, very active. Workflow: establish project principles once
  (`/speckit-constitution`), then per feature: specify → plan → break
  into tasks → implement → converge, each a slash command. Verified
  `--integration claude` is a real, supported option, and that its
  extensions/presets write command files directly into a project's own
  `.claude/commands/` at install time — meaning once initialized, it
  becomes real, git-tracked repo content, not a machine-dependent global
  install (unlike `agency-agents`). The operator's own framing — this
  could help direct programming work without a programming background —
  holds up: the core skill it demands is writing a clear specification,
  which fits the operator's own stated working style (thorough analysis
  before deciding). Genuinely complementary to `working-with-me.md`'s
  lighter-weight "scope before changing code" rule, not overlapping with
  it — Spec Kit is a full formal pipeline per feature; the existing rule
  is a general standing habit.
