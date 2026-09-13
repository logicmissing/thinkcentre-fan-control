# Architecture

How this system is supposed to fit together. Written to the six questions
in `.claude/rules/architecture-doc-guide.md`. A file tree says where the
code is; this says what is allowed to talk to what, and why.

## 1. What exists?

```
  Tray (UI)        CLI (probe)      Capture (dev tool, no hardware)
      \                |                   /
       \               |                  /
        +----------> Tcfc.Core <---------+ <---- Tcfc.Tests
                         |
          +--------------+--------------+
          |              |              |
      PawnIO driver    WMI           WMI
      (ring 0)      root\wmi       root\wmi
          |         GameZone       BiosSetting
          |              |              |
     EC ports          fan mode      BIOS NVRAM
     0x62/0x66         (instant)     (needs restart)
     + CPU MSRs
```

Three separate hardware channels sit behind one façade. They are not
interchangeable and they do not behave alike — see question 4.

## 2. Who owns what?

| Component | Owns |
|---|---|
| `Tcfc.Core/EcReader` | The ACPI embedded-controller read handshake. Fan tach and the raw EC temperature block. **Read only — there is deliberately no EC write path.** |
| `Tcfc.Core/CpuTemps` | Per-core CPU temperature via Intel MSRs `0x1A2` and `0x19C`. Read only. |
| `Tcfc.Core/FanModes` | The instant firmware fan mode, through the Lenovo GameZone WMI class. |
| `Tcfc.Core/BiosCooling` | Exactly one BIOS setting, `IntelligentCoolingPerformanceMode`. Nothing else in the BIOS is ever touched. |
| `Tcfc.Core/FanControl` | The single selector the UI sees. Hides the fact that two unrelated mechanisms are involved. |
| `Tcfc.Core/MachineGuard` | Which board is allowed to be written to, and the RPM byte decode. |
| `Tcfc.Core/TempSummary` | Reducing the unlabeled EC temperature block to one honest display value. |
| `Tcfc.Tray` | All UI: the tray icon, `DashboardForm`, autostart, polling. |
| `Tcfc.Cli` | Verifying a hardware claim on a real machine, by hand. |
| `Tcfc.Capture` | Rendering the README GIF. Touches no hardware at all. |

## 3. What may depend on what?

Allowed: `Tray / CLI / Capture / Tests -> Tcfc.Core -> driver + WMI`.

`Tcfc.Core` depends on nothing in this repo. That is what keeps it
testable, and it is why `Tcfc.Core` is the only project with tests.

**Forbidden:**

- **No UI project talks to the hardware directly.** No `PawnIoNative`, no
  port numbers, no MSR numbers, no WMI class names outside `Tcfc.Core`.
  If the UI needs a new fact from the machine, add it to Core.
- **`Tcfc.Core` never references a UI project**, and never opens a dialog
  or writes to the console. It throws `EcUnavailableException` and lets
  the caller decide how to say it.
- **Nothing writes to the EC.** Reads use the documented ACPI `RD_EC`
  handshake. Every *change* goes through a vendor-supported WMI
  interface instead. This is the core safety decision of the project.

## 4. How does data move?

**Reading (once a second, while the tray is open):**

`Timer -> EcReader (take Global\Access_EC mutex, RD_EC handshake, release)
-> MachineGuard.RpmOrNull -> Tray/Dashboard label`, and in parallel
`CpuTemps -> per-core values -> hottest core -> window graph + tray text`.

**Changing the fan (user picks a mode):**

`DashboardForm -> FanControl.Set(selection)`, which then splits:

- Quiet / Balanced / Performance → `FanModes.Set` → GameZone WMI →
  **takes effect immediately.**
- Full Speed → `BiosCooling.SetFullSpeed(true)` → BIOS NVRAM →
  **takes effect on the next restart.** `FanControl.IsRestartPending`
  is what drives the "restart needed" banner.
- Leaving Full Speed applies the new mode *and* clears the BIOS value,
  and the fan drops back at once — it is only asymmetric on the way in.

## 5. What must stay true?

- **No raw EC writes, ever.** Read-only on the EC; changes ride the
  vendor's own interface.
- **A write is gated on the verified board.** `MachineGuard`
  `IsSupportedBoard` — currently baseboard `3376` only — and `FanModes.Set`
  re-checks it even if a caller forgot to. Unverified boards get
  monitoring, never writes. Widening this needs a real machine, not an
  argument.
- **A failed read never becomes a fake number.** `-1` sentinels stay
  `null` all the way to the UI, which shows "n/a". This project exists
  *because* other tools report a confident `0`. Do not become one of
  them.
- **Never claim a sensor label that is not verified.** The EC temperature
  block is unlabeled, so the UI says "hottest sensor", not "CPU". See
  `docs/research/temp-labeling.md`.
- **The EC mutex is held per transaction only.** `Global\Access_EC` is
  shared with the firmware; holding it longer starves other users.
- **Only one BIOS setting is ever written**,
  `IntelligentCoolingPerformanceMode`, and only when its value is
  actually changing.

## 6. When should Claude stop?

Stop, explain, and propose the smallest change that does not break the
boundary — rather than routing around it — if a task would need any of:

- an EC **write** path, for any reason;
- hardware access from a UI project, or a port/MSR/WMI name outside
  `Tcfc.Core`;
- loosening `MachineGuard` to cover a board nobody has measured;
- showing a value the hardware did not actually return (a default, a
  last-known value, a zero) in place of "n/a";
- re-attempting the 0–100% fan slider. That was write-tested and the
  mechanism does not exist on this hardware — see
  `docs/research/ec-decode-m70t.md` before spending a single turn on it.
