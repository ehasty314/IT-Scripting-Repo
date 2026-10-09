# Windows Service Desk Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)
![Scripts](https://img.shields.io/badge/scripts-30-informational)
![Lint](https://img.shields.io/badge/PSScriptAnalyzer-0%20warnings-brightgreen)

A collection of PowerShell scripts for day-to-day Windows endpoint support, built from real Tier 2 service desk and systems administration work. The toolkit covers the tickets that come up most: slow or crashing PCs, low disk space, profile corruption, printer problems, Group Policy troubleshooting and new-PC deployment.

## Highlights

- **Ticket-ready diagnostics.** Pull hardware health, crash history, shutdown timelines, recent installs and live performance data in seconds, locally or against a remote PC.
- **Safe cleanup.** Clear temp files, Teams cache and the Configuration Manager cache with confirmations, `-WhatIf` previews and a before/after free-space report.
- **Profile management done properly.** Profiles are removed through Windows' own `Win32_UserProfile` API, so the folder and registry entry go together and in-use profiles are protected.
- **Deployment automation.** Post-imaging setup and Windows Autopilot registration, with no credentials stored in code.
- **Consistent design.** Every script has built-in help, accepts parameters, prompts for anything missing, and passes PSScriptAnalyzer with no warnings.

## Quick start

```powershell
# 1. Download the repository
git clone https://github.com/ehasty314/it-scripting-repo.git
cd it_scripting_repo

# 2. Allow scripts for this PowerShell window only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 3. Read a script's help, then run it
Get-Help .\Diagnostics\Get-HardwareReport.ps1 -Full
.\Diagnostics\Get-HardwareReport.ps1
```

### Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 or PowerShell 7+
- Administrator rights for scripts marked **Admin** below
- For remote scripts: WinRM/CIM access and admin rights on the target computer

## Repository layout

```
it-scripts/
├── Diagnostics/    Read-only health checks and troubleshooting reports
├── Network/        Adapter info, speed tests and printer control
├── Maintenance/    Cleanup, updates, BitLocker and sign-out
├── Profiles/       User profile backup and removal
└── Deployment/     New-PC setup and Autopilot registration
```

## Common ticket workflows

| Ticket | Run this |
|---|---|
| "My computer is slow" | `Get-PerformanceSnapshot.ps1`, then `Get-StartupPrograms.ps1` |
| "My computer keeps restarting or crashing" | `Get-ShutdownHistory.ps1`, then `Get-HardwareReport.ps1` |
| "It worked yesterday" | `Get-RecentInstalls.ps1` and `Get-RecentSystemErrors.ps1` |
| Low disk space | `Get-DiskSpace.ps1`, then `Invoke-DiskCleanup.ps1` |
| Corrupt or temp profile | `Backup-UserProfiles.ps1`, then `Remove-UserProfile.ps1` |
| Policy or drive mappings not applying | `Get-GroupPolicyHistory.ps1` |
| Printer offline or stuck | `Get-Printers.ps1`, then `Restart-NetworkPrinter.ps1` |
| BIOS or firmware update | `Get-BitLockerStatus.ps1 -Suspend` before flashing |
| Who is using this PC? | `Get-LoggedOnUsers.ps1` or `Get-RecentLogons.ps1` |
| Battery draining fast | `Get-BatteryHealth.ps1 -Report` |

## Script reference

**Admin** = run from an elevated PowerShell window. **Remote** = supports `-ComputerName` (or a remote target parameter).

### Diagnostics

| Script | What it does | Admin | Remote |
|---|---|:-:|:-:|
| `Get-SystemInfo.ps1` | Model, OS version/build, memory, logged-on user, last boot and uptime | | ✓ |
| `Get-BiosInfo.ps1` | BIOS manufacturer, version, release date and serial number | | ✓ |
| `Get-DiskSpace.ps1` | Size, used and free space for each fixed drive, highlighting drives low on space | | ✓ |
| `Get-BatteryHealth.ps1` | Charge state and wear level; `-Report` opens the full powercfg battery report | | |
| `Get-DisplayInfo.ps1` | Graphics adapters, drivers, resolution, VRAM, health status and attached monitors | | |
| `Get-HardwareReport.ps1` | Full hardware snapshot with disk health, temperatures and crash/WHEA errors; optionally collects BSOD dumps | ✓ | |
| `Get-PerformanceSnapshot.ps1` | Live CPU, memory, disk and network load with the top processes right now | | |
| `Get-InstalledSoftware.ps1` | Installed programs (64-bit, 32-bit and per-user) with filtering and CSV export | | |
| `Get-StartupPrograms.ps1` | Programs that run at startup or sign-in, and whether each is enabled | | ✓ |
| `Get-Printers.ps1` | Installed printers with status, default flag, port and driver | | ✓ |
| `Get-LoggedOnUsers.ps1` | Who is signed in right now, including Remote Desktop and disconnected sessions | | ✓ |
| `Get-RecentLogons.ps1` | Who signed in over the last N days (in person, Remote Desktop or unlock) | ✓ | |
| `Get-ShutdownHistory.ps1` | Timeline of startups, shutdowns, restarts and crashes, including who started each shutdown | | ✓ |
| `Get-GroupPolicyHistory.ps1` | Recent Group Policy refreshes, new settings applied, and GP errors | | ✓ |
| `Get-RecentSystemErrors.ps1` | Most recent Critical and Error events from the System log | | ✓ |
| `Get-RecentInstalls.ps1` | MSI installs, failed installs and removals in the last N days | | ✓ |

### Network

| Script | What it does | Admin | Remote |
|---|---|:-:|:-:|
| `Get-NetworkAdapters.ps1` | Connected adapters with MAC address and link speed (`-All` for every adapter) | | ✓ |
| `Test-InternetSpeed.ps1` | Ookla Speedtest CLI; run once or use `-Iterations 5` for averages | | |
| `Restart-NetworkPrinter.ps1` | Power-cycles a network printer over SNMP | | ✓ |

### Maintenance

| Script | What it does | Admin | Remote |
|---|---|:-:|:-:|
| `Invoke-DiskCleanup.ps1` | Runs the Teams, CCM cache and temp cleanups together and reports space recovered | ✓ | |
| `Clear-TempFiles.ps1` | Deletes old files from every user's Temp folder; supports `-WhatIf` | ✓ | |
| `Clear-TeamsCache.ps1` | Clears classic and new Teams cache for other profiles on the computer | ✓ | |
| `Clear-CCMCache.ps1` | Clears the Configuration Manager client cache through the client's own API | ✓ | |
| `Get-BitLockerStatus.ps1` | BitLocker status per volume; `-Suspend` before BIOS or firmware updates | ✓ | |
| `Install-WindowsUpdates.ps1` | Installs all available updates via PSWindowsUpdate and asks before restarting | ✓ | |
| `Invoke-Logoff.ps1` | Signs out the current user, with confirmation | | |

### Profiles

| Script | What it does | Admin | Remote |
|---|---|:-:|:-:|
| `Backup-UserProfiles.ps1` | Copies Desktop, Documents, Favorites and Pictures for every profile on a remote PC to a share, with a log | ✓ | ✓ |
| `Remove-UserProfile.ps1` | Interactive profile deletion (folder and registry), oldest first, plus orphaned registry key cleanup | ✓ | |

### Deployment

| Script | What it does | Admin | Remote |
|---|---|:-:|:-:|
| `Initialize-Win11Image.ps1` | Post-imaging setup: time zone, resolution, remote management, updates, Autopilot and rename | ✓ | |
| `Register-AutopilotDevice.ps1` | Uploads the hardware hash to Windows Autopilot using interactive sign-in or an app registration | ✓ | |

## Examples

```powershell
# Check a remote PC's uptime, model and OS build
.\Diagnostics\Get-SystemInfo.ps1 -ComputerName PC-1234

# Five speed tests, 30 seconds apart, with averages
.\Network\Test-InternetSpeed.ps1 -Iterations 5 -DelaySeconds 30

# Preview a temp cleanup, then run it for files older than 3 days
.\Maintenance\Clear-TempFiles.ps1 -Days 3 -WhatIf
.\Maintenance\Clear-TempFiles.ps1 -Days 3

# Export all Adobe products on this PC to a spreadsheet
.\Diagnostics\Get-InstalledSoftware.ps1 -Name '*Adobe*' -ExportPath .\adobe.csv

# Back up every profile on a remote PC before reimaging it
.\Profiles\Backup-UserProfiles.ps1 -ComputerName PC-1234 -Destination \\fileserver\Backups
```

## Design conventions

- **Help built in:** every script includes comment-based help with a synopsis, parameters and examples.
- **Parameters first, prompts as a fallback:** scripts can run unattended, or interactively when a value is missing.
- **Confirm before destructive actions:** deletions and restarts ask first; `-Force` skips the prompt when you need automation.
- **CIM over WMI:** `Get-CimInstance` and `Get-WinEvent` work in both Windows PowerShell 5.1 and PowerShell 7.
- **Fail softly:** locked files, missing hardware and unreachable computers produce a clear message instead of a wall of red text.

## Safety

`Remove-UserProfile.ps1` and the cleanup scripts delete data. Back up first with `Backup-UserProfiles.ps1`, and preview with `-WhatIf` where it is supported.

No credentials, tenant IDs, internal hostnames or file shares are stored in this repository. Anything sensitive is passed as a parameter or entered at a prompt at run time.

These scripts are provided as-is. Test them in your own environment before using them in production.

## About

Built and maintained by Emmitt, a systems administrator working in healthcare IT. The scripts started as one-off fixes for service desk tickets and grew into a toolkit used daily for endpoint support.
