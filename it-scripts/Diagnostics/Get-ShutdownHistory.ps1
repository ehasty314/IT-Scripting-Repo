<#
.SYNOPSIS
    Timeline of startups, shutdowns, restarts and crashes, including who or what started each shutdown.

.DESCRIPTION
    Reads the System event log:
      1074  Shutdown/restart started by a user or program (shows which user, process and reason)
      6006  Clean shutdown (event log service stopped)
      6008  Previous shutdown was UNEXPECTED (crash, power loss, held power button)
      41    Kernel-Power: system rebooted without shutting down cleanly
      1001  BugCheck (blue screen)
      6005  Startup (event log service started)

.PARAMETER Days
    How far back to look. Defaults to 14.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-ShutdownHistory.ps1 -Days 30
#>
[CmdletBinding()]
param(
    [int]$Days = 14,
    [string]$ComputerName = $env:COMPUTERNAME
)

$since = (Get-Date).AddDays(-$Days)

# 1001 is filtered by provider so we only get BugCheck, not other events that share the ID
$events = @(
    Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
        LogName = 'System'; Id = 1074, 6005, 6006, 6008, 41; StartTime = $since }
    Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
        LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since }
) | Sort-Object TimeCreated

if (-not $events) {
    Write-Host "No startup or shutdown events found in the last $Days day(s)." -ForegroundColor Yellow
    return
}

$timeline = foreach ($e in $events) {
    switch ($e.Id) {
        1074 {
            # Properties: 0 = process, 2 = reason, 4 = type (restart / power off), 6 = user
            $p = $e.Properties
            [PSCustomObject]@{ Time = $e.TimeCreated; Event = "Requested $($p[4].Value)"
                Detail = "By $($p[6].Value) via $(Split-Path $p[0].Value -Leaf) - $($p[2].Value)"; Color = 'Yellow' }
        }
        6006 { [PSCustomObject]@{ Time = $e.TimeCreated; Event = 'Clean shutdown';        Detail = '';                                   Color = 'Gray' } }
        6008 { [PSCustomObject]@{ Time = $e.TimeCreated; Event = 'UNEXPECTED shutdown';   Detail = ($e.Message -split "`r?`n")[0];       Color = 'Red' } }
        41   { [PSCustomObject]@{ Time = $e.TimeCreated; Event = 'Kernel-Power reboot';   Detail = 'Rebooted without a clean shutdown'; Color = 'Red' } }
        1001 { [PSCustomObject]@{ Time = $e.TimeCreated; Event = 'Blue screen (BugCheck)'; Detail = ($e.Message -split "`r?`n")[0];      Color = 'Red' } }
        6005 { [PSCustomObject]@{ Time = $e.TimeCreated; Event = 'Startup';               Detail = '';                                   Color = 'Green' } }
    }
}

Write-Host "Startup/shutdown history for $ComputerName, last $Days day(s) (oldest first):`n" -ForegroundColor Cyan
foreach ($t in $timeline) {
    Write-Host ('{0:yyyy-MM-dd HH:mm:ss}  {1,-24} {2}' -f $t.Time, $t.Event, $t.Detail) -ForegroundColor $t.Color
}

$unexpected = @($timeline | Where-Object Color -eq 'Red').Count
Write-Host "`n$unexpected unexpected shutdown / crash event(s) in this period." -ForegroundColor $(if ($unexpected) { 'Red' } else { 'Green' })
