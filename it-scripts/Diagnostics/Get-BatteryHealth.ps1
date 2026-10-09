<#
.SYNOPSIS
    Shows battery charge, charging state and wear level, and can generate the full Windows battery report.

.DESCRIPTION
    Reads live battery data from WMI and calculates battery health as
    (current full-charge capacity / original design capacity). With -Report it also runs
    `powercfg /batteryreport` and opens the HTML report.

.PARAMETER Report
    Also generate the detailed powercfg HTML battery report.

.PARAMETER ReportPath
    Where to save the HTML report. Defaults to battery-report.html on the current user's desktop.

.EXAMPLE
    .\Get-BatteryHealth.ps1
    .\Get-BatteryHealth.ps1 -Report
#>
[CmdletBinding()]
param(
    [switch]$Report,
    [string]$ReportPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'battery-report.html')
)

$status = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
if (-not $status) {
    Write-Host 'No battery detected on this computer.' -ForegroundColor Yellow
    return
}

$fullCharge = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue
$static     = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue
$battery    = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

# Multiple batteries are possible (some business laptops have two)
for ($i = 0; $i -lt @($status).Count; $i++) {
    $s      = @($status)[$i]
    $full   = @($fullCharge)[$i].FullChargedCapacity
    $design = @($static)[$i].DesignedCapacity

    $health = if ($full -and $design) { [math]::Round($full / $design * 100, 1) } else { $null }

    [PSCustomObject]@{
        Battery               = $s.InstanceName
        'Charge %'            = @($battery)[$i].EstimatedChargeRemaining
        'Plugged In'          = $s.PowerOnline
        Charging              = $s.Charging
        Discharging           = $s.Discharging
        'Design Capacity mWh' = $design
        'Full Charge mWh'     = $full
        'Health %'            = $health
        Assessment            = if ($null -eq $health) { 'Unknown' }
                                elseif ($health -ge 80) { 'Good' }
                                elseif ($health -ge 60) { 'Worn - monitor' }
                                else { 'Replace recommended' }
    } | Format-List
}

if ($Report) {
    powercfg /batteryreport /output "$ReportPath" | Out-Null
    if (Test-Path $ReportPath) {
        Write-Host "Battery report saved to $ReportPath" -ForegroundColor Green
        Invoke-Item $ReportPath
    } else {
        Write-Host 'powercfg did not produce a report.' -ForegroundColor Red
    }
}
