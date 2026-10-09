<#
.SYNOPSIS
    Runs one or more Ookla Speedtest CLI tests and reports download, upload and ping.

.DESCRIPTION
    Downloads the official Ookla Speedtest CLI on first run (into a per-user tools folder),
    then runs the requested number of tests. With more than one test it also reports the
    average of each metric. Works on Windows PowerShell 5.1 and PowerShell 7 (Windows/Linux).

.PARAMETER Iterations
    How many tests to run. Defaults to 1.

.PARAMETER DelaySeconds
    Pause between tests when running more than one. Defaults to 60.

.EXAMPLE
    .\Test-InternetSpeed.ps1
    .\Test-InternetSpeed.ps1 -Iterations 5 -DelaySeconds 30

.NOTES
    Running the CLI means accepting Ookla's license/GDPR terms (--accept-license --accept-gdpr).
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 50)][int]$Iterations = 1,
    [ValidateRange(0, 3600)][int]$DelaySeconds = 60
)

$version = '1.2.0'
# $IsWindows only exists on PowerShell 6+; on 5.1 we are always on Windows
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows

if ($onWindows) {
    $toolDir = Join-Path $env:LOCALAPPDATA 'SpeedtestCLI'
    $exe     = Join-Path $toolDir 'speedtest.exe'
    $url     = "https://install.speedtest.net/app/cli/ookla-speedtest-$version-win64.zip"
    $archive = Join-Path $toolDir 'speedtest.zip'
} elseif ($IsLinux) {
    $toolDir = Join-Path $HOME '.local/share/speedtest-cli'
    $exe     = Join-Path $toolDir 'speedtest'
    $url     = "https://install.speedtest.net/app/cli/ookla-speedtest-$version-linux-x86_64.tgz"
    $archive = Join-Path $toolDir 'speedtest.tgz'
} else {
    Write-Error 'Unsupported OS.'
    exit 1
}

# --- Install CLI if needed ---------------------------------------------------
if (-not (Test-Path $exe)) {
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $installed = $false
    for ($attempt = 1; $attempt -le 3 -and -not $installed; $attempt++) {
        try {
            Write-Host "Downloading Speedtest CLI (attempt $attempt/3)..."
            Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing -ErrorAction Stop
            if ($onWindows) {
                Expand-Archive -Path $archive -DestinationPath $toolDir -Force
            } else {
                tar -xzf $archive -C $toolDir
                chmod +x $exe
            }
            Remove-Item $archive -ErrorAction SilentlyContinue
            $installed = $true
        } catch {
            Write-Warning "Download failed: $($_.Exception.Message)"
            Start-Sleep -Seconds 5
        }
    }
    if (-not $installed) {
        Write-Error 'Could not install Speedtest CLI after 3 attempts.'
        exit 1
    }
}

# --- Run tests ---------------------------------------------------------------
$results = @()
for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "Running speed test $i of $Iterations..."
    try {
        $json = & $exe --accept-license --accept-gdpr --format=json | ConvertFrom-Json
        # bandwidth is reported in bytes/second; x8 / 1,000,000 = megabits/second
        $row = [PSCustomObject]@{
            Test          = $i
            DownloadMbps  = [math]::Round($json.download.bandwidth * 8 / 1e6, 2)
            UploadMbps    = [math]::Round($json.upload.bandwidth * 8 / 1e6, 2)
            PingMs        = [math]::Round($json.ping.latency, 2)
            JitterMs      = [math]::Round($json.ping.jitter, 2)
            Server        = "$($json.server.name) ($($json.server.location))"
        }
        $results += $row
        $row | Format-List
    } catch {
        Write-Warning "Test $i failed: $($_.Exception.Message)"
    }
    if ($i -lt $Iterations -and $DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
}

if ($results.Count -gt 1) {
    Write-Host "Averages over $($results.Count) successful test(s):" -ForegroundColor Cyan
    [PSCustomObject]@{
        DownloadMbps = [math]::Round(($results.DownloadMbps | Measure-Object -Average).Average, 2)
        UploadMbps   = [math]::Round(($results.UploadMbps   | Measure-Object -Average).Average, 2)
        PingMs       = [math]::Round(($results.PingMs       | Measure-Object -Average).Average, 2)
    } | Format-List
}
