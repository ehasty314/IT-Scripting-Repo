<#
.SYNOPSIS
    Lists software installed or removed recently, based on Windows Installer events.

.DESCRIPTION
    Reads the Application event log for MsiInstaller events:
      11707 = install succeeded, 11708 = install failed, 11724 = product removed.
    Useful for "it was working yesterday" tickets.

    Note: only MSI-based installers log these events. Store apps and many EXE installers
    (and per-user installs such as some Teams/Zoom builds) will not appear.

.PARAMETER Days
    How many days back to look. Defaults to 7.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-RecentInstalls.ps1 -Days 14
#>
[CmdletBinding()]
param(
    [int]$Days = 7,
    [string]$ComputerName = $env:COMPUTERNAME
)

$actions = @{ 11707 = 'Installed'; 11708 = 'Install FAILED'; 11724 = 'Removed' }

# -ErrorAction SilentlyContinue: Get-WinEvent throws an error when nothing matches
$events = Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'MsiInstaller'
    Id           = 11707, 11708, 11724
    StartTime    = (Get-Date).AddDays(-$Days)
}

if (-not $events) {
    Write-Host "No MSI install/removal events in the last $Days day(s)." -ForegroundColor Green
    return
}

$events | Select-Object TimeCreated,
    @{ Name = 'Action';  Expression = { $actions[$_.Id] } },
    @{ Name = 'Product'; Expression = { if ($_.Message -match 'Product:\s*(.+?)\s*--') { $Matches[1] } else { $_.Message } } } |
    Format-Table -AutoSize -Wrap
