<#
.SYNOPSIS
    Interactively deletes local Windows user profiles, including their registry entries.

.DESCRIPTION
    Lists user profiles on this computer with owner name, size and last-use date, then
    deletes the ones you select after a double confirmation.

    Profiles are removed through the Win32_UserProfile CIM class, the same mechanism as
    System Properties > User Profiles > Delete. That removes the folder AND the matching
    ProfileList registry key together, and refuses to remove a profile that is currently
    loaded, so you don't end up with half-deleted profiles or TEMP-profile sign-ins.

    It then checks for orphaned ProfileList registry keys (key exists, folder is gone) and
    offers to remove them. System accounts are never touched.

.PARAMETER Exclude
    Profile folder names that are never listed or deleted.
    Defaults to Administrator and defaultuser0.

.EXAMPLE
    .\Remove-UserProfile.ps1
    .\Remove-UserProfile.ps1 -Exclude Administrator, defaultuser0, kioskuser

.NOTES
    Run as Administrator. Back up anything you need first (see Backup-UserProfiles.ps1).
    Deletion is permanent.
#>
[CmdletBinding()]
param(
    [string[]]$Exclude = @('Administrator', 'defaultuser0')
)

#Requires -RunAsAdministrator

$profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$deletedProfiles = @()
$deletedKeys     = @()

function Get-ProfileOwner {
    param([string]$Sid)
    try {
        (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate(
            [System.Security.Principal.NTAccount]).Value
    } catch {
        'Unknown (account deleted)'
    }
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) } else { '{0:N0} MB' -f ($Bytes / 1MB) }
}

Write-Host @"
*************************************************************
*** WARNING: Deleting a profile is permanent.             ***
*** Back up the user's data before continuing.            ***
*************************************************************
"@ -ForegroundColor Yellow -BackgroundColor Black

do {
    # Special = system/service accounts; Loaded = someone is signed in with it right now
    # Oldest-used first, since stale profiles are usually the ones to clear
    $profiles = @(Get-CimInstance -ClassName Win32_UserProfile |
        Where-Object { -not $_.Special -and $_.LocalPath -like 'C:\Users\*' -and (Split-Path $_.LocalPath -Leaf) -notin $Exclude } |
        Sort-Object LastUseTime)

    if (-not $profiles) {
        Write-Host 'No user profiles found that can be deleted.'
        break
    }

    Write-Host "`nCalculating profile sizes (this can take a moment)..." -ForegroundColor DarkGray
    Write-Host "`nUser profiles on $env:COMPUTERNAME`:"
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $p = $profiles[$i]
        $size = (Get-ChildItem -Path $p.LocalPath -Recurse -Force -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        $state = if ($p.Loaded) { '  [IN USE - cannot delete]' } else { '' }
        $lastUse = if ($p.LastUseTime) { $p.LastUseTime.ToString('yyyy-MM-dd') } else { 'unknown' }
        Write-Host ('  {0,2}) {1,-20} {2,-30} {3,10}  last used {4}{5}' -f `
            ($i + 1), (Split-Path $p.LocalPath -Leaf), (Get-ProfileOwner $p.SID), (Format-Size $size), $lastUse, $state)
    }

    $choice = Read-Host "`nEnter number(s) to delete (e.g. 1,3,4) or press Enter to skip"
    if ([string]::IsNullOrWhiteSpace($choice)) { break }

    $selected = @()
    foreach ($token in ($choice -split '[,\s]+' | Where-Object { $_ })) {
        $n = 0
        if ([int]::TryParse($token, [ref]$n) -and $n -ge 1 -and $n -le $profiles.Count) {
            $p = $profiles[$n - 1]
            if ($p.Loaded) {
                Write-Host "Skipping $(Split-Path $p.LocalPath -Leaf): profile is in use. Have the user sign out (or restart) first." -ForegroundColor Yellow
            } else {
                $selected += $p
            }
        } else {
            Write-Host "Ignoring invalid selection: $token" -ForegroundColor Yellow
        }
    }
    $selected = $selected | Sort-Object SID -Unique

    if (-not $selected) {
        Write-Host 'Nothing valid selected.'
        continue
    }

    $names = ($selected | ForEach-Object { Split-Path $_.LocalPath -Leaf }) -join ', '
    Write-Host "`nSelected for deletion: $names" -ForegroundColor Red
    if ((Read-Host "Type DELETE to permanently remove these profiles") -cne 'DELETE') {
        Write-Host 'Cancelled.'
        continue
    }

    foreach ($p in $selected) {
        $label = '{0} ({1})' -f (Split-Path $p.LocalPath -Leaf), (Get-ProfileOwner $p.SID)
        try {
            $p | Remove-CimInstance -ErrorAction Stop
            $deletedProfiles += $label
            Write-Host "Deleted $label" -ForegroundColor Green
        } catch {
            Write-Host "Failed to delete ${label}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} while ((Read-Host "`nDelete more profiles? (Y/N)") -match '^[Yy]')

# --- Orphaned registry keys --------------------------------------------------
Write-Host "`nChecking for orphaned profile registry keys..." -ForegroundColor Yellow

# S-1-5-18/19/20 are SYSTEM, LocalService and NetworkService; their folders live under C:\Windows
$systemSids = 'S-1-5-18', 'S-1-5-19', 'S-1-5-20'

foreach ($key in Get-ChildItem -Path $profileListPath) {
    $sid = $key.PSChildName
    if ($sid -in $systemSids -or $sid -notlike 'S-1-5-21-*') { continue }

    $imagePath = (Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
    if (-not $imagePath) { continue }
    $imagePath = [Environment]::ExpandEnvironmentVariables($imagePath)
    if (Test-Path $imagePath) { continue }

    Write-Host "Orphaned key: $sid -> $imagePath ($(Get-ProfileOwner $sid))"
    if ((Read-Host '  Remove this registry key? (Y/N)') -match '^[Yy]') {
        try {
            Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction Stop
            $deletedKeys += $sid
            Write-Host '  Removed.' -ForegroundColor Green
        } catch {
            Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# --- Summary -----------------------------------------------------------------
Write-Host @"

*************************************************************
Deleted profiles:      $(if ($deletedProfiles) { $deletedProfiles -join ', ' } else { 'none' })
Removed orphaned keys: $(if ($deletedKeys) { $deletedKeys -join ', ' } else { 'none' })
*************************************************************
Next step: restart if needed and have the user sign in to build a fresh profile.
"@ -ForegroundColor Cyan
