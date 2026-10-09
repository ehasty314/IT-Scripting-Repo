<#
.SYNOPSIS
    Shows the most recent Critical and Error events from the System event log.

.PARAMETER Count
    Number of events to return. Defaults to 20.

.PARAMETER Days
    Only look back this many days. Defaults to 7.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-RecentSystemErrors.ps1 -Count 50 -Days 3
#>
[CmdletBinding()]
param(
    [int]$Count = 20,
    [int]$Days = 7,
    [string]$ComputerName = $env:COMPUTERNAME
)

# Get-EventLog is not available in PowerShell 7; Get-WinEvent works in both.
# Level 1 = Critical, 2 = Error
$events = Get-WinEvent -ComputerName $ComputerName -MaxEvents $Count -ErrorAction SilentlyContinue -FilterHashtable @{
    LogName   = 'System'
    Level     = 1, 2
    StartTime = (Get-Date).AddDays(-$Days)
}

if (-not $events) {
    Write-Host "No critical or error events in the last $Days day(s)." -ForegroundColor Green
    return
}

$events | Select-Object TimeCreated, LevelDisplayName, ProviderName, Id,
    @{ Name = 'Message'; Expression = { ($_.Message -split "`r?`n")[0] } } |
    Format-Table -AutoSize -Wrap
