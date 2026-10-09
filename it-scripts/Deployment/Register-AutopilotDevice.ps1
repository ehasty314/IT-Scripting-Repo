<#
.SYNOPSIS
    Uploads this computer's hardware hash to Windows Autopilot (Intune).

.DESCRIPTION
    Installs Microsoft's Get-WindowsAutopilotInfo script from the PowerShell Gallery and
    registers the device with Autopilot.

    Two ways to authenticate:
      - Interactive (default): you sign in with an account that has Intune rights.
      - App registration: pass -TenantId and -AppId; you are prompted for the client secret
        so it is never stored in the script or shell history.

.PARAMETER GroupTag
    Optional Autopilot group tag to assign.

.PARAMETER TenantId
    Entra ID tenant ID, for app-registration authentication.

.PARAMETER AppId
    Application (client) ID of an app registration with Intune device-enrollment permissions.

.EXAMPLE
    .\Register-AutopilotDevice.ps1
    .\Register-AutopilotDevice.ps1 -GroupTag Kiosk
    .\Register-AutopilotDevice.ps1 -TenantId <tenant-guid> -AppId <app-guid>

.NOTES
    Run as Administrator. NEVER hard-code an app secret in a script or commit one to Git.
#>
[CmdletBinding()]
param(
    [string]$GroupTag,
    [string]$TenantId,
    [string]$AppId
)

#Requires -RunAsAdministrator

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}
if (-not (Get-InstalledScript -Name Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing Get-WindowsAutopilotInfo...'
    Install-Script -Name Get-WindowsAutopilotInfo -Force
}

$autopilotArgs = @{ Online = $true }
if ($GroupTag) { $autopilotArgs.GroupTag = $GroupTag }

if ($TenantId -and $AppId) {
    $secure = Read-Host 'Enter the app registration client secret' -AsSecureString
    $autopilotArgs.TenantId  = $TenantId
    $autopilotArgs.AppId     = $AppId
    $autopilotArgs.AppSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
} elseif ($TenantId -or $AppId) {
    Write-Error 'Provide both -TenantId and -AppId for app authentication, or neither for interactive sign-in.'
    exit 1
} else {
    Write-Host 'You will be asked to sign in with an account that has Intune permissions.'
}

Get-WindowsAutopilotInfo.ps1 @autopilotArgs
