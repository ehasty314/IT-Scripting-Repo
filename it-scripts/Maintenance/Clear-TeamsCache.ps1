<#
.SYNOPSIS
    Clears Microsoft Teams cache for other user profiles on this computer.

.DESCRIPTION
    For each user profile (except the one running the script and built-in profiles), finds
    the Teams cache folders and, after confirmation, deletes their contents. Handles both
    classic Teams (%APPDATA%\Microsoft\Teams) and new Teams (MSTeams package LocalCache).
    Teams must be closed for the affected user, so this is usually run while the user is
    signed out.

.PARAMETER Force
    Skip the per-profile confirmation prompt.

.EXAMPLE
    .\Clear-TeamsCache.ps1

.NOTES
    Run as Administrator to access other users' profiles.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$currentUser = $env:USERNAME
$skip = 'Public', 'Default', 'Default User', 'All Users', $currentUser

# Cache locations relative to the profile root
$cachePaths = @(
    'AppData\Roaming\Microsoft\Teams\Service Worker\CacheStorage',   # classic Teams
    'AppData\Roaming\Microsoft\Teams\Cache',                         # classic Teams
    'AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams'  # new Teams
)

$profiles = Get-ChildItem -Path 'C:\Users' -Directory | Where-Object { $_.Name -notin $skip }
if (-not $profiles) {
    Write-Host 'No other user profiles found.' -ForegroundColor Yellow
    return
}

$cleared = @()
foreach ($p in $profiles) {
    $found = $cachePaths |
        ForEach-Object { Join-Path $p.FullName $_ } |
        Where-Object { Test-Path $_ }

    if (-not $found) {
        Write-Host "No Teams cache found for '$($p.Name)'."
        continue
    }

    if (-not $Force) {
        $answer = Read-Host "Clear Teams cache for '$($p.Name)'? (Y/N)"
        if ($answer -notmatch '^[Yy]') {
            Write-Host "Skipped '$($p.Name)'."
            continue
        }
    }

    $errors = 0
    foreach ($path in $found) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +removeErrors
        $errors += $removeErrors.Count
        $removeErrors = $null
    }

    if ($errors) {
        Write-Host "Cleared Teams cache for '$($p.Name)' with $errors locked item(s) skipped (is Teams still running?)." -ForegroundColor Yellow
    } else {
        Write-Host "Cleared Teams cache for '$($p.Name)'." -ForegroundColor Green
    }
    $cleared += $p.Name
}

Write-Host ''
Write-Host "Profiles cleared: $(if ($cleared) { $cleared -join ', ' } else { 'none' })" -ForegroundColor Cyan
