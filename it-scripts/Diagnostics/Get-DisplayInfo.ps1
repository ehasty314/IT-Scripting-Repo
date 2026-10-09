<#
.SYNOPSIS
    Shows graphics adapters, driver versions, health status, current resolution and attached monitors.

.DESCRIPTION
    Combines graphics-card details (name, status, driver version/date, resolution, refresh rate,
    VRAM) with the list of connected monitors. Flags any adapter whose status is not "OK".
    Optionally saves everything to a text file.

.PARAMETER LogPath
    Optional file to save the results to.

.EXAMPLE
    .\Get-DisplayInfo.ps1
    .\Get-DisplayInfo.ps1 -LogPath "$env:USERPROFILE\Desktop\DisplayInfo.txt"
#>
[CmdletBinding()]
param(
    [string]$LogPath
)

function Convert-WmiString {
    # Monitor names in WMI are stored as arrays of character codes
    param([uint16[]]$Codes)
    if ($Codes) { -join ($Codes | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) }
}

# --- Graphics adapters -------------------------------------------------------
$adapters = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue

$adapterInfo = foreach ($a in $adapters) {
    # VRAM: AdapterRAM is 32-bit and caps at 4 GB, so prefer the 64-bit registry value when present
    $vramBytes = $a.AdapterRAM
    $regKey = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DriverDesc -eq $a.Name } | Select-Object -First 1
    if ($regKey.'HardwareInformation.qwMemorySize') { $vramBytes = $regKey.'HardwareInformation.qwMemorySize' }

    [PSCustomObject]@{
        Name          = $a.Name
        Status        = $a.Status
        DriverVersion = $a.DriverVersion
        DriverDate    = if ($a.DriverDate) { $a.DriverDate.ToString('yyyy-MM-dd') }
        Resolution    = if ($a.CurrentHorizontalResolution) { "$($a.CurrentHorizontalResolution) x $($a.CurrentVerticalResolution)" } else { 'n/a' }
        RefreshHz     = $a.CurrentRefreshRate
        'VRAM (GB)'   = if ($vramBytes) { [math]::Round($vramBytes / 1GB, 1) }
    }
}

# --- Monitors ----------------------------------------------------------------
$monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue |
    ForEach-Object {
        [PSCustomObject]@{
            Manufacturer = Convert-WmiString $_.ManufacturerName
            Model        = Convert-WmiString $_.UserFriendlyName
            Serial       = Convert-WmiString $_.SerialNumberID
            Active       = $_.Active
        }
    }

# --- Output ------------------------------------------------------------------
$report = @(
    'Graphics Adapters'
    '-----------------'
    if ($adapterInfo) { $adapterInfo | Format-List | Out-String } else { "Unable to read graphics adapter information.`n" }
    'Monitors'
    '--------'
    if ($monitors) { $monitors | Format-Table -AutoSize | Out-String } else { "No monitor information available (common over RDP or with some docks).`n" }
)
$report | Write-Host

foreach ($a in $adapterInfo) {
    if ($a.Status -ne 'OK') {
        Write-Host "WARNING: '$($a.Name)' reports status '$($a.Status)'. Check Device Manager and consider reinstalling the driver." -ForegroundColor Red
    }
}
if ($adapterInfo -and -not ($adapterInfo | Where-Object Status -ne 'OK')) {
    Write-Host 'All graphics adapters report status OK.' -ForegroundColor Green
}

if ($LogPath) {
    $report | Set-Content -Path $LogPath
    Write-Host "Saved to $LogPath" -ForegroundColor Green
}
