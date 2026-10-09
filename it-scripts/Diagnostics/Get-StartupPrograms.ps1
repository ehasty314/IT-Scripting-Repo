<#
.SYNOPSIS
    Lists programs that start automatically when Windows starts or a user signs in.

.DESCRIPTION
    Shows entries from the Run registry keys and Startup folders (via Win32_StartupCommand),
    with an "Enabled" column that reflects whether the item was turned off in Task Manager.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine. (The Enabled column is local only.)

.EXAMPLE
    .\Get-StartupPrograms.ps1
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME
)

# Task Manager records disabled items here; first byte 2 or 6 = enabled, 3 or 7 = disabled
$approvedKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
)
$disabled = @{}
if ($ComputerName -eq $env:COMPUTERNAME) {
    foreach ($key in $approvedKeys) {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($p in $props.PSObject.Properties | Where-Object { $_.Value -is [byte[]] }) {
            if ($p.Value[0] -band 1) { $disabled[$p.Name] = $true }
        }
    }
}

$items = Get-CimInstance -ClassName Win32_StartupCommand -ComputerName $ComputerName

if (-not $items) {
    Write-Host 'No startup programs found.' -ForegroundColor Yellow
    return
}

$items | Select-Object Name,
    @{ Name = 'Enabled'; Expression = {
        if ($ComputerName -ne $env:COMPUTERNAME) { 'n/a' }
        elseif ($disabled[$_.Name] -or $disabled[(Split-Path $_.Command -Leaf)]) { 'No' } else { 'Yes' } } },
    User, Location, Command |
    Sort-Object Name | Format-Table -AutoSize -Wrap
