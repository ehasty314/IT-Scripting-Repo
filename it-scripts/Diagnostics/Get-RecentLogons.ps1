<#
.SYNOPSIS
    Shows which people signed in to this computer recently (in person, by Remote Desktop,
    or by unlocking), with first and last sign-in times.

.DESCRIPTION
    Reads successful logon events (4624) from the Security log and keeps only sign-ins by
    real people: interactive (2), unlock (7), Remote Desktop (10) and cached credentials (11).
    Service accounts, SYSTEM, machine accounts and Windows' own background logons are filtered out.

.PARAMETER Days
    How far back to look. Defaults to 2.

.PARAMETER Detailed
    List every sign-in event instead of one summary row per user.

.EXAMPLE
    .\Get-RecentLogons.ps1
    .\Get-RecentLogons.ps1 -Days 7 -Detailed

.NOTES
    Run as Administrator (the Security log requires it).
#>
[CmdletBinding()]
param(
    [int]$Days = 2,
    [switch]$Detailed
)

#Requires -RunAsAdministrator

$logonTypes = @{ 2 = 'Interactive'; 7 = 'Unlock'; 10 = 'Remote Desktop'; 11 = 'Cached' }

# Filtering by LogonType in XPath is far faster than pulling every 4624 event
$xpath = "*[System[EventID=4624 and TimeCreated[timediff(@SystemTime) <= $([int64]$Days * 86400000)]]]" +
         " and *[EventData[Data[@Name='LogonType']=2 or Data[@Name='LogonType']=7 or Data[@Name='LogonType']=10 or Data[@Name='LogonType']=11]]"

$events = Get-WinEvent -LogName Security -FilterXPath $xpath -ErrorAction SilentlyContinue

$logons = foreach ($e in $events) {
    $xml  = [xml]$e.ToXml()
    $data = @{}
    foreach ($d in $xml.Event.EventData.Data) { $data[$d.Name] = $d.'#text' }

    $user = $data['TargetUserName']
    if (-not $user -or $user -like '*$' -or $user -match '^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-\d+|UMFD-\d+|ANONYMOUS LOGON)$') { continue }

    [PSCustomObject]@{
        Time      = $e.TimeCreated
        User      = "$($data['TargetDomainName'])\$user"
        LogonType = $logonTypes[[int]$data['LogonType']]
        SourceIP  = if ($data['IpAddress'] -and $data['IpAddress'] -ne '-') { $data['IpAddress'] } else { 'local' }
    }
}

if (-not $logons) {
    Write-Host "No user sign-ins found in the last $Days day(s)." -ForegroundColor Yellow
    return
}

if ($Detailed) {
    $logons | Format-Table -AutoSize
} else {
    $logons | Group-Object User | ForEach-Object {
        $times = $_.Group.Time | Sort-Object
        [PSCustomObject]@{
            User        = $_.Name
            'Sign-ins'  = $_.Count
            'First'     = $times[0]
            'Last'      = $times[-1]
            Types       = ($_.Group.LogonType | Sort-Object -Unique) -join ', '
            SourceIPs   = ($_.Group.SourceIP | Sort-Object -Unique) -join ', '
        }
    } | Sort-Object Last -Descending | Format-Table -AutoSize
}
