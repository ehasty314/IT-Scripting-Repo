<#
.SYNOPSIS
    Signs out the current user without shutting down or restarting the computer.

.PARAMETER Force
    Skip the confirmation prompt.

.NOTES
    Unsaved work in open applications will be lost.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

if (-not $Force) {
    $answer = Read-Host "Sign out $env:USERNAME now? Unsaved work will be lost. (Y/N)"
    if ($answer -notmatch '^[Yy]') {
        Write-Host 'Cancelled.'
        return
    }
}

shutdown.exe /l
