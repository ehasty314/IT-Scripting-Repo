<#
.SYNOPSIS
    Backs up common user-profile folders from a remote Windows computer to a network share.

.DESCRIPTION
    Copies Desktop, Documents, Favorites and Pictures for every real user profile on the
    target computer using Robocopy. Before copying, it verifies the computer is reachable
    and that the name you typed resolves to the machine that answers (guards against stale
    DNS). Every step, plus basic OS info and per-folder Robocopy results, is written to a
    timestamped log file.

.PARAMETER ComputerName
    The computer to back up. Prompted for if omitted.

.PARAMETER Destination
    Root of the backup share. A subfolder named after the computer is created under it.
    Prompted for if omitted.

.PARAMETER Folders
    Profile subfolders to copy. Defaults to Desktop, Documents, Favorites, Pictures.

.EXAMPLE
    .\Backup-UserProfiles.ps1 -ComputerName PC-1234 -Destination \\fileserver\Backups

.NOTES
    Requires admin rights on the target (access to the C$ share).
#>
[CmdletBinding()]
param(
    [string]$ComputerName,
    [string]$Destination,
    [string[]]$Folders = @('Desktop', 'Documents', 'Favorites', 'Pictures')
)

if (-not $ComputerName) { $ComputerName = Read-Host 'Enter the name of the computer to back up' }
if (-not $Destination)  { $Destination  = Read-Host 'Enter the backup share root (e.g. \\fileserver\Backups)' }

$ComputerName = $ComputerName.Trim()
$Destination  = $Destination.TrimEnd('\')
$logFile = Join-Path $PSScriptRoot ("Backup_{0}_{1:yyyyMMdd_HHmmss}.log" -f $ComputerName, (Get-Date))

function Write-BackupLog {
    param([string]$Message, [string]$Color = 'Gray')
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $logFile -Value $line
}

function Exit-WithError {
    param([string]$Message)
    Write-BackupLog $Message 'Red'
    Read-Host 'Press Enter to exit' | Out-Null
    exit 1
}

# --- Pre-flight checks -------------------------------------------------------
Write-BackupLog "Starting backup of $ComputerName"

if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
    Exit-WithError "$ComputerName is not reachable."
}

try {
    $remoteName = (Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop).Name
} catch {
    Exit-WithError "Could not query $ComputerName over CIM: $($_.Exception.Message)"
}

# Compare short names so an FQDN entry (pc.domain.local) still matches
$shortName = $ComputerName.Split('.')[0]
if ($shortName -ne $remoteName) {
    Exit-WithError "Name mismatch: you entered '$ComputerName' but the machine reports '$remoteName'. Possible stale DNS."
}

$os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName
Write-BackupLog ("OS: {0} ({1}), build {2}" -f $os.Caption, $os.OSArchitecture, $os.BuildNumber)

# --- Backup ------------------------------------------------------------------
$usersRoot  = "\\$ComputerName\C$\Users"
$backupRoot = Join-Path $Destination $ComputerName
$skip       = 'Public', 'Default', 'Default User', 'All Users'

$profiles = Get-ChildItem -Path $usersRoot -Directory -ErrorAction Stop |
    Where-Object { $_.Name -notin $skip }

$failures = 0
foreach ($profileDir in $profiles) {
    foreach ($folder in $Folders) {
        $src = Join-Path $profileDir.FullName $folder
        $dst = Join-Path (Join-Path $backupRoot $profileDir.Name) $folder

        if (-not (Test-Path $src)) {
            Write-BackupLog "Skipped: $($profileDir.Name)\$folder (not found)"
            continue
        }

        # /E = include empty subfolders, /R /W = short retry, /NP /NFL /NDL = quiet output
        robocopy $src $dst /E /R:2 /W:5 /NP /NFL /NDL /NJH | Out-Null
        # Robocopy exit codes 0-7 are success; 8+ means at least one failure
        if ($LASTEXITCODE -ge 8) {
            $failures++
            Write-BackupLog "FAILED: $($profileDir.Name)\$folder (robocopy exit code $LASTEXITCODE)" 'Red'
        } else {
            Write-BackupLog "Copied: $($profileDir.Name)\$folder" 'Green'
        }
    }
}

if ($failures) {
    Write-BackupLog "Backup finished with $failures failure(s). Destination: $backupRoot" 'Yellow'
} else {
    Write-BackupLog "Backup completed successfully. Destination: $backupRoot" 'Green'
}
Write-BackupLog "Log saved to $logFile"
Read-Host 'Press Enter to exit' | Out-Null
