# ThinkCentre Fan Control — Continuity & Orientation

**Read this file fully before doing anything else.** It is the single
source of truth for where this project stands and how to work in it. Keep
it current — when a workstream's status changes, edit its section here in
the same session, not "later."

**Keep this file itself small** — roughly under 200 lines / ~2,000
tokens. It loads on every session; padding it out degrades
instruction-following rather than improving it. Anything that grows past
a paragraph belongs in `.claude/rules/` (conventions) or `.claude/docs/`
(reference), not here.

**How this fits with other memory files:** Claude Code layers memory — a
global/user-level file, then this project's `CLAUDE.md`, then any
subfolder's own file — and the most specific one wins where they
conflict. `.claude/docs/about-me.md` is the "who is the operator" layer
that stays constant across projects; this file is the "what is this
project" layer underneath it.

## 1. What this project is

A **Windows desktop utility, open source (MIT), for Lenovo ThinkCentre and
ThinkStation desktops.** It shows the real fan RPM — which every other tool
on these machines reports as `0` — plus per-core CPU temperatures, and it
exposes the fan modes including a **Full Speed** setting Lenovo Vantage
hides. It ships as a tray app (`Tcfc.Tray`) with a dashboard window, and a
small CLI (`Tcfc.Cli`) used for probing and verification.

**This is a software-engineering project, not a personal/analysis one.**
All the code rules in `.claude/rules/` apply — see
`working-with-me.md`'s "match ceremony to the project's nature".

**What the working environment means for you — read this before promising
anything works:**

- The app is **Windows-only**: .NET 8, WinForms, WMI, and ring-0 register
  reads through the [PawnIO](https://pawnio.eu/) signed driver. A cloud
  session runs on Linux with **no .NET SDK installed** — verified, not
  assumed. You cannot build it, run it, or run its tests here.
- It also needs **real hardware**. Every meaningful path reads an embedded
  controller or a CPU MSR on an actual ThinkCentre, elevated. Unit tests
  cover only the pure decode/mapping functions.
- So: a code change made in a cloud session is **written, not verified**.
  Say that plainly when handing it back, and name what has to be run on
  Windows to close the gap. See `.claude/rules/coding-conventions.md`,
  "Done means it ran". The operator is the one who runs it and reports
  back.
- Only **one board is verified**: ThinkCentre M70t Gen 6, baseboard
  product `3376`. `MachineGuard.IsSupportedBoard` gates every write on it.
  Never widen that gate on reasoning alone — it needs a real machine.

## 2. How to navigate this repo

```
CLAUDE.md / README.md      <- this file; the public page for the app
LICENSE                    <- MIT. This project IS meant to be shared, unlike the template default.
.claude/
  settings.json             <- permissions (committed); settings.local.json is personal + gitignored
  project.env               <- project-wide constants (PROJECT_TZ)
  hooks/                    <- session-start.sh (what this container can/cannot do), dream-check.sh
  commands/                 <- /dream, /template-sync, /bootstrap-project
  rules/                    <- always-loaded conventions, one topic per file (Section 5)
  docs/                     <- about-me, architecture (the six questions), reviewed-tools,
                               reference/ (raw ground truth to grep; empty - see Section 4)
src/
  Tcfc.Core/                <- all hardware logic. net8.0-windows, no UI. The only tested project.
  Tcfc.Cli/                 <- console probe: monitor, temps, mode. How findings get verified on metal.
  Tcfc.Tray/                <- the shipped app: tray icon + DashboardForm. WinForms.
  Tcfc.Capture/             <- dev-only. Renders the README demo GIF. No hardware, no elevation.
tests/Tcfc.Tests/           <- xunit. Pure functions only (decode, parse, mapping, guards).
scripts/recon/              <- read-only PowerShell probes for mapping a NEW board; see its README
docs/
  specs/                    <- the design spec, dated
  research/                 <- ground truth: ACPI decompiles, EC probes, measured behavior,
                               per-board notes; recon/ holds the raw M70t captures
.github/                    <- PR/issue templates, CONTRIBUTING, SECURITY, CODEOWNERS, dependabot
.template-sync.yaml         <- links this project back to General-Template, see /template-sync
```

## 3. Current state — read this before writing any new code

### 3.1 The app itself

- **Confirmed / working (run on real hardware):** EC read path, RPM decode,
  `FanModes.Get`, per-core CPU temps via MSR, the tray, the dashboard
  window, and the Full Speed BIOS path. Evidence:
  `docs/research/v1-cli-verify.md` and the measurement table in
  `docs/research/temp-labeling.md`. Latest work was cosmetic — app icon,
  window layout, README.
- **Open questions:** the EC temperature block at `0x21..0x2F` is not
  labeled. Offset `0x26` reads 111 under load, which is not a plausible
  degrees-C value, so `TempSummary` only ever claims "hottest sensor",
  never "CPU". Mapping those offsets to real components needs more
  hardware measurement, not more reasoning.
- **Built, not yet verified:** nothing outstanding.
- **Known dead end, do not re-attempt:** a true 0–100% fan slider. `_FIF`
  advertises fine-grain control, but `FNSL` is a *method* in a
  runtime-loaded DPTF table, not a writable EC field — so there is no
  register to reach it from outside. Write-tested and confirmed absent.
  Full working is in `docs/research/ec-decode-m70t.md`. The README
  already tells users this honestly; keep it that way.

### 3.2 Project scaffolding

- **Confirmed / working:** the `General-Template` scaffold is in place —
  11 rule files, three slash commands, both session hooks, `.github/`
  files. Both hooks were run here and behave correctly.
- **Built, not yet verified:** `/dream` and `/template-sync`, never run here.
- **Next steps:** none. Run `/template-sync` when the template gains
  something worth pulling down.

### 3.3 Second board: ThinkCentre M710q (board `3111`)

- **Confirmed / working:** nothing on that hardware yet. `scripts/recon/`
  now holds three read-only probe scripts — ACPI tables, Lenovo WMI and
  BIOS settings, EC RAM `0x00`–`0xFF` — plus `Test-ReconCommon.ps1`
  (55 passing tests over the shared logic). `scripts/recon/README.md` is
  the operator-facing procedure.
- **Open questions:** the deciding one is now whether this board has a
  Super I/O monitoring chip — the M70t had none, which is the only reason
  its fan needed EC reverse-engineering at all. The operator reports
  HWMonitor showing a real fan RPM there while LibreHardwareMonitor shows
  none, which the M70t never did; see `docs/research/m710q-3111-notes.md`
  for what that does and does not establish. Behind it: does a physical EC
  answer on 0x62/0x66, does `LENOVO_GAMEZONE_DATA` exist on a 2017 board,
  and what does that BIOS call its cooling setting. Each is settled by a
  run, not by reasoning.
- **Built, not yet verified:** every Windows-only path in those scripts.
  Only the pure logic and the failure branches have been run, on Linux.
- **Watch out:** `EcReader` reads the M70t's offsets on *any* board — only
  writes are gated. RPM and EC temps shown on a 3111 today are unverified
  numbers, not readings. Per-core CPU temps are the exception.
- **Next steps:** identify the chip above the fan readings in the tool
  that shows them. A Super I/O chip name means the answer is FanControl and
  this repo's EC route is unnecessary here; anything else means running
  `scripts/recon/README.md` steps 1–7 and returning
  `docs/research/recon-3111/`. Build nothing further — no EC-diff harness,
  no per-board map — until that is settled.

## 4. How to look things up instead of guessing

This project has unusually good ground truth. **Grep it before guessing** —
this is the concrete case behind the verification-first habit in
`coding-conventions.md`.

- `docs/research/ec-decode-m70t.md` — what the ACPI tables actually
  contain, and the proof that the fan slider is not reachable.
- `docs/research/temp-labeling.md` — measured idle-to-load behavior of
  every EC temperature offset, and why only "hottest sensor" is claimed.
- `docs/research/v1-cli-verify.md` — the on-hardware RPM numbers the code
  is expected to reproduce.
- `docs/research/recon/` — the raw captured ACPI tables (`.bin`) and probe
  logs behind all of the above.
- `docs/specs/2026-07-08-...-design.md` — the approved design and the
  three fan-control channels that were evaluated.

This habit has already paid for itself once: the original design assumed
a writable `FNSL` EC byte. Reading the decompiled tables killed that
assumption before any code was written against it.

`.claude/docs/reference/` is empty. Put third-party specs there (an ACPI
spec extract, a PawnIO reference) if a future task needs one.

## 5. Project conventions

Working conventions live in `.claude/rules/` and load automatically — don't
duplicate their content here. One line each, read the file for the rest:

- `coding-conventions.md` — the general ones, including "done means it ran".
- `versioning-and-archival.md` — timestamps in `PROJECT_TZ`, archive on
  supersede. Applies to generated docs; the C# source is versioned by git.
- `bug-class-checks.md` — name a recurring bug class, sweep before delivery.
- `issue-logging.md` — how a confirmed bug gets recorded.
- `session-export.md` — how a handoff between sessions gets recorded.
- `working-with-me.md` — read `about-me.md` once; scope before changing code.
- `architecture-doc-guide.md` — the six questions, already answered for this
  project in `.claude/docs/architecture.md`.
- `loop-engineering.md` — the L1/L2/L3 ladder for unattended agents.
- `response-style.md` — flag uncertainty; be concise without cutting what
  matters.
- `reasoning-triggers.md` — words that ask for a specific reasoning mode.
- `model-delegation.md` — delegate narrow subtasks to a cheaper model; also
  records which slash commands work in cloud sessions.

## 6. What did NOT make it into this repo

Brought over from `General-Template` at commit `d67355a`. Deliberately
left behind:

- **`.claude/rules/excel-conventions.md` and
  `process-engineering-conventions.md`** — VBA/Power Query and
  chemical-process rules. Nothing here is either. Every rule file loads
  in every session, so dropping them is a real recurring saving.
- **All vendored skills** (`.claude/skills/` — ICM architect, ~230 files
  of pump/fluids/distillation engineering skills). They cost roughly
  4,900 tokens of description per session and none of it is about
  Windows, C#, or embedded controllers. Restorable from the source repos
  listed in `.claude/docs/reviewed-tools.md`.
- **The template's own build history** —
  `.claude/docs/backlog-review-checkpoint.md` and its PR audit report
  describe how the template was built, not this app.

Note: `.claude/docs/reviewed-tools.md` was copied whole and still
describes the *template's* decisions — its "Vendored into this repo"
table lists skills that are **not** in this repo. It is kept for its
verdicts, so tools already rejected don't get re-researched.
