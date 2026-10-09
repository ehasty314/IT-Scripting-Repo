<#
.SYNOPSIS
    Hardware health snapshot: system, CPU, memory, disks (with health), battery, network,
    temperatures and recent crash/hardware errors. Optionally collects BSOD dump files.

.PARAMETER Days
    How far back to look for crash and hardware errors. Defaults to 7.

.PARAMETER DumpDestination
    If set, copies minidump (.dmp) files to this folder or share, in a subfolder named after
    this computer. Leave empty to skip.

.EXAMPLE
    .\Get-HardwareReport.ps1
    .\Get-HardwareReport.ps1 -DumpDestination \\fileserver\BSOD

.NOTES
    Run as Administrator for disk health, temperature and minidump access.
    Temperature readings depend on the manufacturer's ACPI support and are often unavailable.
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$DumpDestination
)

function Write-Section { param([string]$Title) Write-Host "`n$Title" -ForegroundColor Cyan; Write-Host ('-' * $Title.Length) }

# --- System / CPU / Memory ---------------------------------------------------
$cs   = Get-CimInstance -ClassName Win32_ComputerSystem
$cpus = Get-CimInstance -ClassName Win32_Processor
$mem  = Get-CimInstance -ClassName Win32_PhysicalMemory

Write-Section 'System'
[PSCustomObject]@{
    Manufacturer = $cs.Manufacturer
    Model        = $cs.Model
    Serial       = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
} | Format-List

Write-Section 'Processor'
$cpus | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors,
    @{ Name = 'Load %'; Expression = { $_.LoadPercentage } } | Format-Table -AutoSize

Write-Section 'Memory'
$mem | Select-Object @{ Name = 'Slot'; Expression = { $_.DeviceLocator } },
    @{ Name = 'Size (GB)'; Expression = { [math]::Round($_.Capacity / 1GB) } },
    @{ Name = 'Speed (MHz)'; Expression = { $_.Speed } }, Manufacturer, PartNumber | Format-Table -AutoSize
Write-Host ('Total: {0} GB' -f [math]::Round(($mem | Measure-Object Capacity -Sum).Sum / 1GB))

# --- Disks -------------------------------------------------------------------
Write-Section 'Disks'
# Get-PhysicalDisk gives media type and a real health status (needs admin on some systems)
$physical = Get-PhysicalDisk -ErrorAction SilentlyContinue
if ($physical) {
    $physical | Select-Object FriendlyName, MediaType, BusType,
        @{ Name = 'Size (GB)'; Expression = { [math]::Round($_.Size / 1GB) } },
        HealthStatus, OperationalStatus | Format-Table -AutoSize
} else {
    Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model,
        @{ Name = 'Size (GB)'; Expression = { [math]::Round($_.Size / 1GB) } }, Status | Format-Table -AutoSize
}

# --- Battery -----------------------------------------------------------------
Write-Section 'Battery'
$battery = Get-CimInstance -ClassName Win32_Battery
if ($battery) {
    $statusText = @{ 1 = 'Discharging'; 2 = 'On AC power'; 3 = 'Fully charged'; 4 = 'Low'; 5 = 'Critical';
                     6 = 'Charging'; 7 = 'Charging (high)'; 8 = 'Charging (low)'; 9 = 'Charging (critical)';
                     10 = 'Undefined'; 11 = 'Partially charged' }
    $battery | Select-Object Name,
        @{ Name = 'Status';   Expression = { $statusText[[int]$_.BatteryStatus] } },
        @{ Name = 'Charge %'; Expression = { $_.EstimatedChargeRemaining } } | Format-Table -AutoSize
    Write-Host 'For wear level, run Get-BatteryHealth.ps1.'
} else {
    Write-Host 'No battery (desktop).'
}

# --- Network -----------------------------------------------------------------
Write-Section 'Network Adapters (physical)'
Get-CimInstance -ClassName Win32_NetworkAdapter -Filter 'PhysicalAdapter = TRUE' |
    Select-Object Name, NetConnectionID,
        @{ Name = 'Connected'; Expression = { $_.NetConnectionStatus -eq 2 } },
        @{ Name = 'Speed (Mbps)'; Expression = { if ($_.Speed) { [math]::Round($_.Speed / 1e6) } } } |
    Format-Table -AutoSize

# --- Temperature -------------------------------------------------------------
Write-Section 'Temperature (ACPI thermal zones)'
$zones = Get-CimInstance -Namespace root\wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
if ($zones) {
    # Reported in tenths of a Kelvin
    $zones | Select-Object InstanceName,
        @{ Name = 'Temp (C)'; Expression = { [math]::Round(($_.CurrentTemperature - 2731.5) / 10, 1) } } | Format-Table -AutoSize
} else {
    Write-Host 'Not available on this hardware (or not running as Administrator).'
}

# --- Crash / hardware errors -------------------------------------------------
Write-Section "Crash and hardware errors (last $Days days)"
# 41 = unexpected restart/power loss, 1001 = BugCheck (BSOD), WHEA-Logger = hardware errors
$since = (Get-Date).AddDays(-$Days)
$crashEvents = @(
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41; StartTime = $since } -ErrorAction SilentlyContinue
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since } -ErrorAction SilentlyContinue
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $since } -ErrorAction SilentlyContinue
) | Sort-Object TimeCreated -Descending

if ($crashEvents) {
    Write-Host "$($crashEvents.Count) event(s) found:" -ForegroundColor Red
    $crashEvents | Select-Object TimeCreated, ProviderName, Id,
        @{ Name = 'Message'; Expression = { ($_.Message -split "`r?`n")[0] } } | Format-Table -AutoSize -Wrap
} else {
    Write-Host 'None found.' -ForegroundColor Green
}

# --- Minidumps ---------------------------------------------------------------
$dumps = Get-ChildItem -Path "$env:SystemRoot\Minidump" -Filter '*.dmp' -ErrorAction SilentlyContinue
Write-Section 'Crash dumps'
if (-not $dumps) {
    Write-Host 'No minidump files found.'
} else {
    $dumps | Select-Object Name, LastWriteTime | Format-Table -AutoSize
    if ($DumpDestination) {
        $target = Join-Path $DumpDestination $env:COMPUTERNAME
        try {
            New-Item -ItemType Directory -Path $target -Force -ErrorAction Stop | Out-Null
            $dumps | Copy-Item -Destination $target -Force -ErrorAction Stop
            Write-Host "Copied $($dumps.Count) dump file(s) to $target" -ForegroundColor Green
        } catch {
            Write-Host "Could not copy dumps to ${target}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
