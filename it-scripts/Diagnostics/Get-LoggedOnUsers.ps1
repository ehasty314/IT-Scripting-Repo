<#
.SYNOPSIS
    Shows who is signed in to a computer right now, including Remote Desktop and disconnected sessions.

.DESCRIPTION
    Uses `quser` to list every session (console, RDP and disconnected), with logon time and
    idle time. On a domain-joined computer it also looks up each user's display name in
    Active Directory.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-LoggedOnUsers.ps1
    .\Get-LoggedOnUsers.ps1 -ComputerName PC-1234
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME
)

function Get-DisplayName {
    param([string]$SamAccountName)
    try {
        $result = ([adsisearcher]"(&(objectCategory=user)(sAMAccountName=$SamAccountName))").FindOne()
        if ($result) { [string]$result.Properties['displayname'] }
    } catch { $null }   # not domain-joined or no DC reachable
}

$raw = quser /server:$ComputerName 2>&1
if ($LASTEXITCODE -ne 0 -or -not $raw) {
    Write-Host "No users are signed in to $ComputerName (or it could not be queried)." -ForegroundColor Yellow
    return
}

# quser columns: USERNAME  SESSIONNAME  ID  STATE  IDLE TIME  LOGON TIME
# SESSIONNAME is blank for disconnected sessions, so it's optional in the pattern
$pattern = '^[\s>]*(?<user>\S+)\s+(?:(?<session>\S+)\s+)?(?<id>\d+)\s+(?<state>Active|Disc)\s+(?<idle>\S+)\s+(?<logon>.+?)\s*$'

$sessions = foreach ($line in ($raw | Select-Object -Skip 1)) {
    if ("$line" -match $pattern) {
        [PSCustomObject]@{
            User        = $Matches.user
            DisplayName = Get-DisplayName $Matches.user
            Session     = if ($Matches.session) { $Matches.session } else { '(none)' }
            State       = if ($Matches.state -eq 'Disc') { 'Disconnected' } else { 'Active' }
            IdleTime    = $Matches.idle
            LogonTime   = $Matches.logon
        }
    }
}

Write-Host "Sessions on ${ComputerName}:" -ForegroundColor Cyan
$sessions | Format-Table -AutoSize
