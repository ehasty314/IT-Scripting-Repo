<#
.SYNOPSIS
    Lists installed software with version, publisher and install date.

.DESCRIPTION
    Reads all three places Windows records installed programs:
      - 64-bit machine-wide installs (HKLM\SOFTWARE\...\Uninstall)
      - 32-bit machine-wide installs (HKLM\SOFTWARE\WOW6432Node\...\Uninstall)
      - Per-user installs for the current user (HKCU\...\Uninstall)
    Windows updates and system components are hidden. Matches what Apps & Features shows
    much more closely than reading the 64-bit key alone.

.PARAMETER Name
    Only show programs whose name matches this wildcard, e.g. "*Chrome*".

.PARAMETER ExportPath
    Optional CSV file to export the list to.

.EXAMPLE
    .\Get-InstalledSoftware.ps1
    .\Get-InstalledSoftware.ps1 -Name '*Adobe*'
    .\Get-InstalledSoftware.ps1 -ExportPath "$env:USERPROFILE\Desktop\software.csv"
#>
[CmdletBinding()]
param(
    [string]$Name = '*',
    [string]$ExportPath
)

$keys = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';             Scope = 'Machine (64-bit)' }
    @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Scope = 'Machine (32-bit)' }
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';             Scope = 'Current user' }
)

$software = foreach ($k in $keys) {
    Get-ItemProperty -Path $k.Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName -and $_.DisplayName -like $Name } |
        ForEach-Object {
            $date = $null
            if ($_.InstallDate -match '^\d{8}$') { $date = [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd') }
            [PSCustomObject]@{
                Name        = $_.DisplayName.Trim()
                Version     = $_.DisplayVersion
                Publisher   = $_.Publisher
                InstallDate = $date
                Scope       = $k.Scope
            }
        }
}

$software = $software | Sort-Object Name, Version -Unique

if (-not $software) {
    Write-Host "No installed software matches '$Name'." -ForegroundColor Yellow
    return
}

$software | Format-Table -AutoSize
Write-Host "$(@($software).Count) program(s) found."

if ($ExportPath) {
    $software | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Exported to $ExportPath" -ForegroundColor Green
}
