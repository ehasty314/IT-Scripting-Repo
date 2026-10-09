<#
.SYNOPSIS
    Deletes old files from every user's Temp folder (and optionally the Windows Temp folder).

.DESCRIPTION
    Removes items older than -Days from C:\Users\*\AppData\Local\Temp. Files that are in use
    are skipped instead of stopping the whole cleanup. Reports how much space was freed.

.PARAMETER Days
    Only delete items not modified in this many days. Defaults to 7. Use 0 to delete everything.

.PARAMETER IncludeWindowsTemp
    Also clean C:\Windows\Temp.

.EXAMPLE
    # Preview what would be deleted without deleting anything
    .\Clear-TempFiles.ps1 -WhatIf
    .\Clear-TempFiles.ps1 -Days 3 -IncludeWindowsTemp

.NOTES
    Run as Administrator to reach other users' Temp folders.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateRange(0, 3650)][int]$Days = 7,
    [switch]$IncludeWindowsTemp
)

$cutoff  = (Get-Date).AddDays(-$Days)
$targets = @(Get-ChildItem -Path 'C:\Users\*\AppData\Local\Temp' -Directory -Force -ErrorAction SilentlyContinue)
if ($IncludeWindowsTemp) { $targets += Get-Item 'C:\Windows\Temp' }

$freed = 0; $deleted = 0; $skipped = 0

foreach ($temp in $targets) {
    # Files first, then empty folders, so a folder isn't deleted while its newer files remain
    $files = Get-ChildItem -Path $temp.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    foreach ($f in $files) {
        if ($PSCmdlet.ShouldProcess($f.FullName, 'Delete')) {
            try {
                $size = $f.Length
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $freed += $size; $deleted++
            } catch {
                $skipped++   # usually locked by a running program
            }
        }
    }

    # Remove folders that are now empty (deepest first)
    Get-ChildItem -Path $temp.FullName -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove empty folder')) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
}

Write-Host ('Deleted {0} file(s), freed {1:N1} MB. Skipped {2} file(s) that were in use.' -f $deleted, ($freed / 1MB), $skipped) -ForegroundColor Green
