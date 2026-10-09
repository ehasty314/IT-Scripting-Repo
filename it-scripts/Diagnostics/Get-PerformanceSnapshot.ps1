<#
.SYNOPSIS
    "What's eating my CPU?" Shows current CPU, memory, disk and network load and the top
    processes by CPU and memory, flagging anything over its threshold.

.DESCRIPTION
    Takes a short sample (default 3 seconds) of performance counters, so the per-process CPU
    numbers reflect what is happening right now, not total CPU time since each process started.

.PARAMETER SampleSeconds
    How long to sample for. Defaults to 3.

.PARAMETER Top
    How many processes to list. Defaults to 5.

.EXAMPLE
    .\Get-PerformanceSnapshot.ps1
    .\Get-PerformanceSnapshot.ps1 -SampleSeconds 10 -Top 10
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 60)][int]$SampleSeconds = 3,
    [ValidateRange(1, 50)][int]$Top = 5
)

function Write-Metric {
    param([string]$Label, [string]$Value, [bool]$Bad)
    Write-Host ('{0,-22} {1}' -f $Label, $Value) -ForegroundColor $(if ($Bad) { 'Red' } else { 'Green' })
}

Write-Host "Sampling for $SampleSeconds second(s)..." -ForegroundColor DarkGray
$counters = Get-Counter -SampleInterval $SampleSeconds -MaxSamples 1 -Counter @(
    '\Processor(_Total)\% Processor Time'
    '\Memory\Available MBytes'
    '\Memory\% Committed Bytes In Use'
    '\PhysicalDisk(_Total)\% Disk Time'
    '\Network Interface(*)\Bytes Total/sec'
    '\Process(*)\% Processor Time'
) -ErrorAction SilentlyContinue

$samples = $counters.CounterSamples
function Get-Sample { param([string]$Like) ($samples | Where-Object Path -like $Like | Select-Object -First 1).CookedValue }

$cpu       = [math]::Round((Get-Sample '*\processor(_total)\% processor time'), 1)
$availMB   = [math]::Round((Get-Sample '*\memory\available mbytes'))
$committed = [math]::Round((Get-Sample '*\memory\% committed bytes in use'), 1)
$disk      = [math]::Min(100, [math]::Round((Get-Sample '*\physicaldisk(_total)\% disk time'), 1))

Write-Host "`nSystem" -ForegroundColor Cyan
Write-Metric 'CPU'              "$cpu %"              ($cpu -gt 80)
Write-Metric 'Memory available' "$availMB MB"         ($availMB -lt 1024)
Write-Metric 'Memory committed' "$committed %"        ($committed -gt 90)
Write-Metric 'Disk busy'        "$disk %"             ($disk -gt 80)

# Bytes/sec x 8 / 1,000,000 = megabits per second
$samples | Where-Object { $_.Path -like '*\network interface(*)\bytes total/sec' -and $_.CookedValue -gt 0 } |
    ForEach-Object {
        $mbps = [math]::Round($_.CookedValue * 8 / 1e6, 2)
        Write-Metric ("Network: " + $_.InstanceName.Substring(0, [math]::Min(13, $_.InstanceName.Length))) "$mbps Mbps" ($mbps -gt 100)
    }

# Per-process % is relative to one core, so divide by the number of logical processors
$cores = [Environment]::ProcessorCount
Write-Host "`nTop $Top processes by CPU (right now)" -ForegroundColor Cyan
$samples | Where-Object { $_.Path -like '*\process(*)\% processor time' -and $_.InstanceName -notin '_total', 'idle' } |
    Sort-Object CookedValue -Descending | Select-Object -First $Top |
    Select-Object @{ Name = 'Process'; Expression = { $_.InstanceName } },
                  @{ Name = 'CPU %';   Expression = { [math]::Round($_.CookedValue / $cores, 1) } } |
    Format-Table -AutoSize

Write-Host "Top $Top processes by memory" -ForegroundColor Cyan
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First $Top |
    Select-Object @{ Name = 'Process'; Expression = { $_.ProcessName } }, Id,
                  @{ Name = 'Memory (MB)'; Expression = { [math]::Round($_.WorkingSet64 / 1MB) } } |
    Format-Table -AutoSize
