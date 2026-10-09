<#
.SYNOPSIS
    Shows BIOS name, manufacturer, version and release date for a local or remote computer.

.PARAMETER ComputerName
    Target computer. Leave blank (or press Enter at the prompt) for the local machine.

.PARAMETER LogPath
    Optional file to append the results to.

.EXAMPLE
    .\Get-BiosInfo.ps1 -ComputerName PC-1234
#>
[CmdletBinding()]
param(
    [string]$ComputerName,
    [string]$LogPath
)

if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
    $ComputerName = Read-Host 'Enter computer name (leave blank for this computer)'
}
if ([string]::IsNullOrWhiteSpace($ComputerName)) { $ComputerName = $env:COMPUTERNAME }

try {
    $bios = Get-CimInstance -ClassName Win32_BIOS -ComputerName $ComputerName -ErrorAction Stop
    $result = [PSCustomObject]@{
        ComputerName = $ComputerName
        BiosName     = $bios.Name
        Manufacturer = $bios.Manufacturer
        Version      = $bios.SMBIOSBIOSVersion
        ReleaseDate  = $bios.ReleaseDate
        SerialNumber = $bios.SerialNumber
    }
    $result | Format-List

    if ($LogPath) {
        $result | Format-List | Out-File -FilePath $LogPath -Append
        Write-Host "Saved to $LogPath" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to get BIOS info from ${ComputerName}: $($_.Exception.Message)" -ForegroundColor Red
}
