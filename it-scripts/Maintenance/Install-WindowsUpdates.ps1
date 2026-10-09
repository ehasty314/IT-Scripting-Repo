<#
.SYNOPSIS
    Checks for and installs all available Windows updates using the PSWindowsUpdate module.

.DESCRIPTION
    Installs the PSWindowsUpdate module from the PowerShell Gallery if needed, lists available
    updates, then installs them. By default you are asked before the computer restarts.

.PARAMETER AutoReboot
    Restart automatically if an update requires it, without asking.

.PARAMETER ListOnly
    Only list available updates; don't install anything.

.EXAMPLE
    .\Install-WindowsUpdates.ps1 -ListOnly
    .\Install-WindowsUpdates.ps1 -AutoReboot

.NOTES
    Run as Administrator. Requires internet access to the PowerShell Gallery on first run.
#>
[CmdletBinding()]
param(
    [switch]$AutoReboot,
    [switch]$ListOnly
)

#Requires -RunAsAdministrator

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host 'Installing PSWindowsUpdate module...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }
    Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force
}
Import-Module PSWindowsUpdate

Write-Host 'Checking for updates...'
$updates = Get-WindowsUpdate

if (-not $updates) {
    Write-Host 'This computer is up to date.' -ForegroundColor Green
    return
}

$updates | Select-Object KB, Size, Title | Format-Table -AutoSize -Wrap
if ($ListOnly) { return }

$installArgs = @{ Install = $true; AcceptAll = $true }
if ($AutoReboot) { $installArgs.AutoReboot = $true } else { $installArgs.IgnoreReboot = $true }

Get-WindowsUpdate @installArgs

if (-not $AutoReboot -and (Get-WURebootStatus -Silent)) {
    if ((Read-Host 'A restart is required to finish installing updates. Restart now? (Y/N)') -match '^[Yy]') {
        Restart-Computer -Force
    } else {
        Write-Host 'Remember to restart to finish installing updates.' -ForegroundColor Yellow
    }
} else {
    Write-Host 'Updates installed.' -ForegroundColor Green
}
