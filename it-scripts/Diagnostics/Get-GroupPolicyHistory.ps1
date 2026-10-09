<#
.SYNOPSIS
    Shows recent Group Policy processing results, including whether new settings were applied
    and any errors or warnings.

.DESCRIPTION
    Reads the Microsoft-Windows-GroupPolicy/Operational log and reports:
      1500 / 1501  Computer / user policy processed, no changes since last time
      1502 / 1503  Computer / user policy processed, NEW settings applied
      Errors and warnings (for example, can't reach a domain controller, or an extension failed)
    Ends with the last successful refresh time for computer and user policy.

.PARAMETER Days
    How far back to look. Defaults to 7.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-GroupPolicyHistory.ps1 -Days 2
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$ComputerName = $env:COMPUTERNAME
)

$log   = 'Microsoft-Windows-GroupPolicy/Operational'
$since = (Get-Date).AddDays(-$Days)
$labels = @{
    1500 = 'Computer policy OK (no changes)'
    1501 = 'User policy OK (no changes)'
    1502 = 'Computer policy OK - NEW settings applied'
    1503 = 'User policy OK - NEW settings applied'
}

# Filter in the query itself rather than loading the whole log and filtering afterwards
$results = Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
    LogName = $log; Id = 1500, 1501, 1502, 1503; StartTime = $since
}
$problems = Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
    LogName = $log; Level = 2, 3; StartTime = $since
}

Write-Host "`nGroup Policy processing on $ComputerName, last $Days day(s)" -ForegroundColor Cyan

if ($results) {
    $results | Select-Object TimeCreated, Id, @{ Name = 'Result'; Expression = { $labels[$_.Id] } } |
        Format-Table -AutoSize

    $changes = @($results | Where-Object Id -in 1502, 1503)
    Write-Host "$($results.Count) refresh(es), $($changes.Count) with new settings applied."
} else {
    Write-Host 'No successful policy refreshes recorded in this period.' -ForegroundColor Yellow
}

if ($problems) {
    Write-Host "`n$(@($problems).Count) error/warning event(s):" -ForegroundColor Red
    $problems | Select-Object TimeCreated, LevelDisplayName, Id,
        @{ Name = 'Message'; Expression = { ($_.Message -split "`r?`n")[0] } } |
        Format-Table -AutoSize -Wrap
    Write-Host 'Tips: check domain controller / VPN connectivity, then run "gpupdate /force" and "gpresult /h report.html".'
} else {
    Write-Host "`nNo Group Policy errors or warnings." -ForegroundColor Green
}

$lastComputer = $results | Where-Object Id -in 1500, 1502 | Select-Object -First 1
$lastUser     = $results | Where-Object Id -in 1501, 1503 | Select-Object -First 1
Write-Host ("`nLast computer policy refresh: {0}" -f $(if ($lastComputer) { $lastComputer.TimeCreated } else { 'none in range' }))
Write-Host ("Last user policy refresh:     {0}" -f $(if ($lastUser) { $lastUser.TimeCreated } else { 'none in range' }))
