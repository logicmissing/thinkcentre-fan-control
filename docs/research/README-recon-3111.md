# Where new-board recon results go

`scripts/recon/` writes its output into `docs/research/recon-<board>/`. For
the M710q work that is `docs/research/recon-3111/`, created on the first run.

Expect these files after a full pass:

| File | From | What it settles |
|---|---|---|
| `acpireg-*.bin` + `acpi-index.txt` | script 1 | Whether this board's ACPI embedded controller is real or a stub, once decompiled with `iasl -d` |
| `wmi-probe.txt` | script 2 | Whether `LENOVO_GAMEZONE_DATA` exists for fan modes, and what this BIOS calls its cooling setting |
| `ec-dump-idle.txt`, `ec-dump-load.txt` | script 3 | Whether a physical EC answers on ports 0x62/0x66, and which bytes move with fan speed |

The equivalent evidence for the verified M70t Gen 6 (board `3376`) is in
`recon/`, with the conclusions written up in `ec-decode-m70t.md` and
`temp-labeling.md`. Read those before interpreting a new board's dumps — they
show which observations turned out to mean something and which did not.
