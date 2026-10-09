<#
.SYNOPSIS
    Remotely power-cycles a network printer over SNMP.

.DESCRIPTION
    Sets the standard Printer-MIB reset object (prtGeneralReset, OID 1.3.6.1.2.1.43.5.1.1.3.1)
    to 4 (powerCycleReset). Most enterprise printers support this, but SNMP write access must
    be enabled on the printer and you need its WRITE community string, which is often not
    "public".

.PARAMETER PrinterIP
    IP address of the printer. Prompted for if omitted.

.PARAMETER Community
    SNMP write community string. Prompted for if omitted.

.PARAMETER Force
    Skip the confirmation prompt.

.EXAMPLE
    .\Restart-NetworkPrinter.ps1 -PrinterIP 10.0.0.50
#>
[CmdletBinding()]
param(
    [string]$PrinterIP,
    [string]$Community,
    [switch]$Force
)

if (-not $PrinterIP) { $PrinterIP = Read-Host 'Printer IP address' }
$parsed = $null
if (-not [System.Net.IPAddress]::TryParse($PrinterIP, [ref]$parsed)) {
    Write-Host "'$PrinterIP' is not a valid IP address." -ForegroundColor Red
    exit 1
}
if (-not $Community) {
    $Community = Read-Host 'SNMP write community string (press Enter for "public")'
    if (-not $Community) { $Community = 'public' }
}

if (-not (Test-Connection -ComputerName $PrinterIP -Count 1 -Quiet)) {
    Write-Host "Printer at $PrinterIP is not responding to ping." -ForegroundColor Red
    exit 1
}

if (-not $Force) {
    if ((Read-Host "Restart the printer at ${PrinterIP}? Any job currently printing will be lost. (Y/N)") -notmatch '^[Yy]') {
        Write-Host 'Cancelled.'
        return
    }
}

$resetOid       = '.1.3.6.1.2.1.43.5.1.1.3.1'
$powerCycle     = 4   # 3 = notResetting, 4 = powerCycleReset, 5 = resetToNVRAM, 6 = resetToFactoryDefaults

$snmp = $null
try {
    $snmp = New-Object -ComObject olePrn.OleSNMP
    $snmp.Open($PrinterIP, $Community, 2, 3000)   # 2 retries, 3 s timeout
    $snmp.Set($resetOid, $powerCycle)
    Write-Host "Restart command sent to $PrinterIP. Allow a few minutes for it to come back online." -ForegroundColor Green
} catch {
    Write-Host "Failed to restart the printer: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Check that SNMP write access is enabled on the printer and the community string is correct.'
} finally {
    if ($snmp) { try { $snmp.Close() } catch { Write-Verbose "SNMP session already closed." } }
}
