<#
.SYNOPSIS
    One-shot disk cleanup for low-space tickets: Teams cache, CCM cache and old temp files,
    with a before/after free-space report.

.DESCRIPTION
    Runs Clear-TeamsCache.ps1, Clear-CCMCache.ps1 and Clear-TempFiles.ps1 (which must be in
    the same folder as this script) without prompting, then shows free space on every drive.

.PARAMETER TempDays
    Passed to Clear-TempFiles.ps1: only delete temp files older than this many days. Defaults to 7.

.PARAMETER SkipCCMCache
    Don't touch the Configuration Manager cache.

.EXAMPLE
    .\Invoke-DiskCleanup.ps1
    .\Invoke-DiskCleanup.ps1 -TempDays 1 -SkipCCMCache

.NOTES
    Run as Administrator.
#>
[CmdletBinding()]
param(
    [int]$TempDays = 7,
    [switch]$SkipCCMCache
)

#Requires -RunAsAdministrator

function Get-CDriveFreeSpace {
    (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
}

$before = Get-CDriveFreeSpace
Write-Host ('Free space on C: before cleanup: {0:N2} GB' -f ($before / 1GB)) -ForegroundColor Cyan

Write-Host "`n== Teams cache ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'Clear-TeamsCache.ps1') -Force

if (-not $SkipCCMCache) {
    Write-Host "`n== Configuration Manager cache ==" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'Clear-CCMCache.ps1') -Force
}

Write-Host "`n== Temp files older than $TempDays day(s) ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'Clear-TempFiles.ps1') -Days $TempDays -IncludeWindowsTemp

$after = Get-CDriveFreeSpace
Write-Host @"

*************************************************************
Space recovered on C:  $('{0:N2}' -f (($after - $before) / 1GB)) GB
Free space on C: now   $('{0:N2}' -f ($after / 1GB)) GB
*************************************************************
"@ -ForegroundColor Green

Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' |
    Select-Object DeviceID,
        @{ Name = 'Size (GB)'; Expression = { [math]::Round($_.Size / 1GB, 2) } },
        @{ Name = 'Free (GB)'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) } },
        @{ Name = 'Free %';    Expression = { if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 1) } } } |
    Format-Table -AutoSize
