<#
.SYNOPSIS
    Shows BitLocker status for each volume and can suspend protection (for BIOS/firmware updates).

.DESCRIPTION
    Reports encryption state, percent encrypted and whether protection is On, Off or SUSPENDED.
    BitLocker reports suspended volumes as ProtectionStatus "Off" while the volume is still
    encrypted, so this script spells that out.

    With -Suspend, protection on the OS drive is suspended for -RebootCount restarts, then
    resumes automatically.

.PARAMETER Suspend
    Suspend BitLocker on the OS drive.

.PARAMETER RebootCount
    How many restarts to stay suspended for (1-15). Defaults to 1.

.EXAMPLE
    .\Get-BitLockerStatus.ps1
    .\Get-BitLockerStatus.ps1 -Suspend -RebootCount 2

.NOTES
    Run as Administrator.
#>
[CmdletBinding()]
param(
    [switch]$Suspend,
    [ValidateRange(1, 15)][int]$RebootCount = 1
)

#Requires -RunAsAdministrator

function Show-Status {
    Get-BitLockerVolume | Select-Object MountPoint, VolumeType, VolumeStatus,
        @{ Name = 'Encrypted %'; Expression = { $_.EncryptionPercentage } },
        @{ Name = 'Protection'; Expression = {
            if ($_.ProtectionStatus -eq 'Off' -and $_.VolumeStatus -ne 'FullyDecrypted') { 'SUSPENDED' }
            else { $_.ProtectionStatus } } } |
        Format-Table -AutoSize
}

Show-Status

if ($Suspend) {
    $osDrive = $env:SystemDrive
    if ((Read-Host "Suspend BitLocker on $osDrive for $RebootCount restart(s)? (Y/N)") -match '^[Yy]') {
        Suspend-BitLocker -MountPoint $osDrive -RebootCount $RebootCount | Out-Null
        Write-Host "BitLocker suspended on $osDrive. It resumes automatically after $RebootCount restart(s)." -ForegroundColor Yellow
        Show-Status
    } else {
        Write-Host 'Cancelled.'
    }
}
