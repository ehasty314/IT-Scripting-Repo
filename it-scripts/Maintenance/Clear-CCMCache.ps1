<#
.SYNOPSIS
    Safely clears the Configuration Manager (SCCM/MECM) client cache (C:\Windows\ccmcache).

.DESCRIPTION
    Uses the Configuration Manager client's own COM API (UIResource.UIResourceMgr) to delete
    cache items. That keeps the client's cache index in sync with what is on disk. Deleting
    files straight out of ccmcache leaves the client thinking content is still cached, which
    can make later installs fail.

    By default, items marked "persist in cache" by the admin are kept. Shows space freed on C:.

.PARAMETER IncludePersisted
    Also delete items an admin marked to persist in cache.

.PARAMETER Force
    Skip the confirmation prompt.

.EXAMPLE
    .\Clear-CCMCache.ps1
    .\Clear-CCMCache.ps1 -Force

.NOTES
    Run as Administrator on a computer with the Configuration Manager client installed.
#>
[CmdletBinding()]
param(
    [switch]$IncludePersisted,
    [switch]$Force
)

#Requires -RunAsAdministrator

function Get-FreeGB {
    [math]::Round((Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
}

try {
    $uiResource = New-Object -ComObject UIResource.UIResourceMgr -ErrorAction Stop
    $cache      = $uiResource.GetCacheInfo()
} catch {
    Write-Host 'The Configuration Manager client is not installed (or not responding) on this computer.' -ForegroundColor Yellow
    return
}

$items = @($cache.GetCacheElements())
if (-not $items) {
    Write-Host 'The CCM cache is already empty.' -ForegroundColor Green
    return
}

# ContentSize is reported in KB
$totalGB = [math]::Round(($items | Measure-Object -Property ContentSize -Sum).Sum / 1MB, 2)
Write-Host "Cache location: $($cache.Location)"
Write-Host "Cache contains $($items.Count) item(s), $totalGB GB."
Write-Host "Free space on C: before: $(Get-FreeGB) GB"

if (-not $Force) {
    if ((Read-Host 'Delete these cache items? (Y/N)') -notmatch '^[Yy]') {
        Write-Host 'Cancelled.'
        return
    }
}

# Second argument: also delete content an admin marked "persist in client cache"
foreach ($item in $items) {
    try {
        $cache.DeleteCacheElementEx($item.CacheElementID, [bool]$IncludePersisted)
    } catch {
        # Usually content in use by an install that is running right now; it is left in place
        Write-Verbose "Could not delete $($item.ContentID): $($_.Exception.Message)"
    }
}

$remaining = @($uiResource.GetCacheInfo().GetCacheElements()).Count
Write-Host ("Deleted {0} item(s). {1} item(s) left (persisted or in use)." -f ($items.Count - $remaining), $remaining) -ForegroundColor Green
Write-Host "Free space on C: after: $(Get-FreeGB) GB"
