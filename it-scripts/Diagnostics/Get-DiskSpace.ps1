<#
.SYNOPSIS
    Shows size, used space and free space for each local fixed drive, flagging drives that are low.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.PARAMETER WarnPercent
    Free-space percentage at or below which a drive is highlighted. Defaults to 15.

.EXAMPLE
    .\Get-DiskSpace.ps1
    .\Get-DiskSpace.ps1 -ComputerName PC-1234 -WarnPercent 10
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [ValidateRange(0, 100)][int]$WarnPercent = 15
)

# DriveType 3 = local fixed disk (excludes USB sticks, DVD drives and mapped network drives)
$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ComputerName $ComputerName

foreach ($d in $drives) {
    $pctFree = if ($d.Size) { [math]::Round($d.FreeSpace / $d.Size * 100, 1) } else { 0 }
    $line = '{0}  {1,8} GB total | {2,8} GB used | {3,8} GB free | {4,5}% free' -f `
        $d.DeviceID,
        [math]::Round($d.Size / 1GB, 2),
        [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 2),
        [math]::Round($d.FreeSpace / 1GB, 2),
        $pctFree

    $color = if ($pctFree -le $WarnPercent) { 'Red' } else { 'Green' }
    Write-Host $line -ForegroundColor $color
}
