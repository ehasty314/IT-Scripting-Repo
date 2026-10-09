<#
.SYNOPSIS
    Lists installed printers with status, default flag, port, driver and whether each is a network printer.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-Printers.ps1
    .\Get-Printers.ps1 -ComputerName PC-1234
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME
)

$statusText = @{ 1 = 'Other'; 2 = 'Unknown'; 3 = 'Idle'; 4 = 'Printing'; 5 = 'Warming up'; 6 = 'Stopped'; 7 = 'Offline' }

$printers = Get-CimInstance -ClassName Win32_Printer -ComputerName $ComputerName

if (-not $printers) {
    Write-Host 'No printers installed.' -ForegroundColor Yellow
    return
}

$printers | Sort-Object -Property @{ Expression = 'Default'; Descending = $true }, Name |
    Select-Object Name,
        @{ Name = 'Default'; Expression = { if ($_.Default) { 'Yes' } } },
        @{ Name = 'Status';  Expression = { if ($_.WorkOffline) { 'Offline' } else { $statusText[[int]$_.PrinterStatus] } } },
        @{ Name = 'Type';    Expression = { if ($_.Network) { 'Network' } else { 'Local' } } },
        PortName, DriverName |
    Format-Table -AutoSize
