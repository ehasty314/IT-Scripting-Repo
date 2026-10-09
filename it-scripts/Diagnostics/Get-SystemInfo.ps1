<#
.SYNOPSIS
    Shows computer name, model, OS version/build, architecture, last boot and uptime.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.EXAMPLE
    .\Get-SystemInfo.ps1 -ComputerName PC-1234
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME
)

# CIM is much faster than Get-ComputerInfo and also works against remote machines
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName
$cs = Get-CimInstance -ClassName Win32_ComputerSystem  -ComputerName $ComputerName

$uptime = (Get-Date) - $os.LastBootUpTime

[PSCustomObject]@{
    ComputerName    = $cs.Name
    Manufacturer    = $cs.Manufacturer
    Model           = $cs.Model
    OS              = $os.Caption
    Version         = $os.Version
    Build           = $os.BuildNumber
    Architecture    = $os.OSArchitecture
    'Memory (GB)'   = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    'Logged-on User'= $cs.UserName
    'Last Boot'     = $os.LastBootUpTime
    Uptime          = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
} | Format-List
