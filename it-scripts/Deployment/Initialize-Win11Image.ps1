<#
.SYNOPSIS
    Post-imaging setup for a new Windows 11 PC: rename, time zone, resolution, remote
    management, Windows updates and Autopilot registration.

.DESCRIPTION
    Each step can be skipped with a switch. Steps run in this order:
      1. Time zone
      2. Display resolution (optional, uses the DisplaySettings module from PSGallery)
      3. Remote management: allow ping, enable WinRM and Remote Desktop (domain/private networks)
      4. Windows updates (installs without restarting)
      5. Autopilot registration (Register-AutopilotDevice.ps1, same folder)
      6. Rename the computer, then offer to restart

.PARAMETER NewName
    New computer name. Prompted for if omitted.

.PARAMETER TimeZone
    Windows time zone ID. Defaults to "Central Standard Time". See Get-TimeZone -ListAvailable.

.PARAMETER Width
    Horizontal resolution to set. If Width/Height are omitted, resolution is left alone.

.PARAMETER Height
    Vertical resolution to set.

.PARAMETER GroupTag
    Optional Autopilot group tag.

.EXAMPLE
    .\Initialize-Win11Image.ps1 -NewName PC-1234 -Width 1920 -Height 1080
    .\Initialize-Win11Image.ps1 -NewName PC-1234 -SkipUpdates -SkipAutopilot

.NOTES
    Run as Administrator.
    Remote management is opened on Domain and Private networks only. Review this against
    your organization's security baseline before using it.
#>
[CmdletBinding()]
param(
    [string]$NewName,
    [string]$TimeZone = 'Central Standard Time',
    [int]$Width,
    [int]$Height,
    [string]$GroupTag,
    [switch]$SkipRemoteManagement,
    [switch]$SkipUpdates,
    [switch]$SkipAutopilot
)

#Requires -RunAsAdministrator

if (-not $NewName) { $NewName = Read-Host 'Enter the new computer name' }
if ($NewName -notmatch '^[A-Za-z0-9-]{1,15}$') {
    Write-Error 'Computer names must be 1-15 characters: letters, numbers and hyphens only.'
    exit 1
}

function Write-Step { param([string]$Text) Write-Host "`n== $Text ==" -ForegroundColor Cyan }

# Only this PowerShell window is affected, not the machine-wide policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# 1. Time zone
Write-Step "Setting time zone to $TimeZone"
Set-TimeZone -Id $TimeZone

# 2. Resolution
if ($Width -and $Height) {
    Write-Step "Setting resolution to ${Width}x${Height}"
    if (-not (Get-Module -ListAvailable -Name DisplaySettings)) { Install-Module -Name DisplaySettings -Force }
    Import-Module DisplaySettings
    Set-DisplayResolution -Width $Width -Height $Height
}

# 3. Remote management
if (-not $SkipRemoteManagement) {
    Write-Step 'Enabling ping, WinRM and Remote Desktop (Domain/Private networks)'

    # WinRM refuses to configure while any network is set to Public
    Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public' |
        Set-NetConnectionProfile -NetworkCategory Private

    if (-not (Get-NetFirewallRule -Name 'Allow-ICMPv4-Echo-In' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'Allow-ICMPv4-Echo-In' -DisplayName 'Allow ICMPv4 echo request (ping)' `
            -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow -Profile Domain, Private | Out-Null
    }

    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null

    # 0 = allow Remote Desktop connections
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
}

# 4. Windows updates
if (-not $SkipUpdates) {
    Write-Step 'Installing Windows updates (no restart yet)'
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) { Install-Module -Name PSWindowsUpdate -Force }
    Import-Module PSWindowsUpdate
    Install-WindowsUpdate -AcceptAll -IgnoreReboot
}

# 5. Autopilot
if (-not $SkipAutopilot) {
    Write-Step 'Registering with Windows Autopilot'
    $autopilotScript = Join-Path $PSScriptRoot 'Register-AutopilotDevice.ps1'
    if ($GroupTag) { & $autopilotScript -GroupTag $GroupTag } else { & $autopilotScript }
}

# 6. Rename last, because it only takes effect after the restart
Write-Step "Renaming computer to $NewName"
if ($env:COMPUTERNAME -ne $NewName) {
    Rename-Computer -NewName $NewName -Force
} else {
    Write-Host 'Already named correctly.'
}

if ((Read-Host "`nSetup complete. Restart now to apply the new name and updates? (Y/N)") -match '^[Yy]') {
    Restart-Computer -Force
} else {
    Write-Host 'Restart later to finish.' -ForegroundColor Yellow
}
