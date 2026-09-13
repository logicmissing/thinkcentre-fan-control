# Recon scripts — map a new board

These three scripts collect the facts that are necessary to add a new
ThinkCentre board to this project. They do the same work that the reference
M70t Gen 6 went through, written down as scripts.

The scripts collect data. They do not change the machine.

## Before you start

Do the two checks below first. They can make all of this unnecessary.

1. Install LibreHardwareMonitor. Run it as an administrator.
2. Look for a chip name in the tree. An example is `Nuvoton NCT6791D`.
3. If you find fan speeds and fan controls below that chip, stop.
   Install FanControl. You do not need this project.
4. If all tools show a fan speed of `0` RPM, continue. Your machine has the
   same problem as the reference machine.

## What you need

- Windows 10 or Windows 11.
- An account with administrator rights.
- The PawnIO driver from pawnio.eu, for script 3 only.
- The file `LpcACPIEC.bin`, for script 3 only. It is in the project release ZIP.

## How to run the scripts

Obey the order. Each script writes its results to
`docs\research\recon-3111\`.

**Step 1. Open PowerShell with administrator rights.**

1. Click the Start button.
2. Type `powershell`.
3. Right-click **Windows PowerShell**.
4. Click **Run as administrator**.
5. Click **Yes** on the permission window.

**Step 2. Go to this folder.**

Use this command. Change the path if your copy is in a different place.

```
cd C:\path\to\thinkcentre-fan-control\scripts\recon
```

**Step 3. Save the ACPI tables.**

```
powershell -ExecutionPolicy Bypass -File .\01-dump-acpi.ps1
```

The script writes one `.bin` file for each table, and an index file. The
reference machine had 22 tables.

**Step 4. Probe the Lenovo WMI interfaces.**

```
powershell -ExecutionPolicy Bypass -File .\02-probe-wmi.ps1
```

The script writes `wmi-probe.txt`. This file answers two important questions.
Does this board have the `LENOVO_GAMEZONE_DATA` class for fan modes? What is
the correct name of the BIOS cooling setting on this board?

**Step 5. Read the embedded controller.**

Install PawnIO first. Then put `LpcACPIEC.bin` in this folder.

Let the machine become idle. Then use this command.

```
powershell -ExecutionPolicy Bypass -File .\03-dump-ec.ps1 -Label idle
```

**Step 6. Read the embedded controller again, under load.**

1. Start a program that makes the CPU busy. Prime95 or Cinebench is
   satisfactory. A large file compression also does this.
2. Wait 60 seconds. Listen to the fan. The fan must be louder.
3. Keep the load running. Use this command in the PowerShell window.

```
powershell -ExecutionPolicy Bypass -File .\03-dump-ec.ps1 -Label load
```

4. Stop the load program.

**Step 7. Send the results back.**

Send the full contents of `docs\research\recon-3111\`.

## What each script does

| Script | Reads | Writes | Needs administrator rights |
|---|---|---|---|
| `01-dump-acpi.ps1` | The registry key `HKLM\HARDWARE\ACPI` | `acpireg-*.bin`, `acpi-index.txt` | Recommended |
| `02-probe-wmi.ps1` | WMI classes in `root\wmi` | `wmi-probe.txt` | Yes |
| `03-dump-ec.ps1` | EC RAM `0x00` to `0xFF` | `ec-dump-<label>.txt` | Yes |

`Recon.Common.ps1` holds the shared functions. `Test-ReconCommon.ps1` tests
them. Do not run those two files as recon steps.

## Safety

These scripts are read-only. This is how that is enforced.

- Script 1 reads the registry. It writes only to the output folder.
- Script 2 calls a WMI method only if the name starts with `Get` or `Is`. It
  refuses any name that mentions a password, a certificate, a key, secure
  boot, a TPM, a wipe, a flash or an update. `Lenovo_SetBiosSetting` and
  `Lenovo_SaveBiosSettings` are never called. The script only reports if they
  are present.
- Script 3 sends two bytes to the EC ports. These two bytes are the read
  command `0x80` and the offset to read. This is the standard ACPI read
  handshake. The script cannot send the write command `0x81`. The port and
  command limits are inside the compiled helper.

Do not write to any EC offset until the two dumps from step 5 and step 6 are
compared. A write to an unknown register is the first action with real risk.

## Test status

`Test-ReconCommon.ps1` tests the shared functions. Run it on any machine:

```
powershell -ExecutionPolicy Bypass -File .\Test-ReconCommon.ps1
```

The tests cover the ACPI header decode, the file name rules, the WMI method
safety gate, the hex dump format, the EC verdict, and the fan value search.
They do not test the hardware access. Only a run on a real machine does that.
