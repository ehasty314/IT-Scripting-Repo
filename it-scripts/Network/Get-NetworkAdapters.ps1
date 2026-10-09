<#
.SYNOPSIS
    Lists network adapters with connection status, MAC address and link speed.

.PARAMETER All
    Include disconnected and virtual adapters. By default only connected adapters are shown.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-NetworkAdapters.ps1
    .\Get-NetworkAdapters.ps1 -All -ComputerName PC-1234
#>
[CmdletBinding()]
param(
    [switch]$All,
    [string]$ComputerName = $env:COMPUTERNAME
)

# NetConnectionStatus 2 = Connected
$filter = if ($All) { 'NetConnectionID IS NOT NULL' } else { 'NetConnectionStatus = 2' }

$adapters = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter $filter -ComputerName $ComputerName

if (-not $adapters) {
    Write-Host 'No matching network adapters found.' -ForegroundColor Yellow
    return
}

$adapters | Select-Object `
    @{ Name = 'Connection'; Expression = { $_.NetConnectionID } },
    Name,
    MACAddress,
    @{ Name = 'SpeedMbps'; Expression = { if ($_.Speed) { [math]::Round($_.Speed / 1e6) } } },
    @{ Name = 'Physical';  Expression = { $_.PhysicalAdapter } },
    NetEnabled |
    Format-Table -AutoSize
