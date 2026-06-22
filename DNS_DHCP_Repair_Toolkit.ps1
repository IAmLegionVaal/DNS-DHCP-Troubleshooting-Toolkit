#requires -Version 5.1
<#
.SYNOPSIS
    Guarded Windows DNS and DHCP repair toolkit.
.DESCRIPTION
    Diagnoses by default and repairs selected DNS, DHCP, adapter and network-stack
    problems only when explicit repair switches are supplied.
.NOTES
    Created by Dewald Pretorius - L2 IT Support Engineer.
#>

[CmdletBinding()]
param(
    [switch]$RepairAllSafe,
    [switch]$FlushDns,
    [switch]$RegisterDns,
    [switch]$RestartClientServices,
    [switch]$RenewDhcp,
    [switch]$RestartAdapter,
    [switch]$SetAutomaticDns,
    [switch]$ResetWinsockTcpIp,
    [string]$AdapterName,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.0'
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ExitCode = 0
$RebootRequired = $false

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "DNS_DHCP_Repair_$Stamp"
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$LogPath = Join-Path $OutputPath 'repair.log'
$BackupPath = Join-Path $OutputPath 'backup'
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DRYRUN')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'DRYRUN'  { Write-Host "DRY RUN: $Message" -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Require-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw 'This repair requires an elevated PowerShell session.'
    }
}

function Confirm-Action {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$HighImpact
    )
    if ($DryRun -or $Yes) { return $true }
    $token = if ($HighImpact) { 'REPAIR' } else { 'YES' }
    return (Read-Host "$Message Type $token to continue") -eq $token
}

function Get-SelectedAdapter {
    if ([string]::IsNullOrWhiteSpace($AdapterName)) {
        throw 'Specify -AdapterName for this action.'
    }
    $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
    if (-not $adapter) {
        throw "Network adapter '$AdapterName' was not found."
    }
    return $adapter
}

function Save-State {
    param([Parameter(Mandatory)][string]$Stage)

    $state = [ordered]@{
        Stage = $Stage
        Generated = (Get-Date).ToString('o')
        ScriptVersion = $ScriptVersion
        Computer = $env:COMPUTERNAME
        User = "$env:USERDOMAIN\$env:USERNAME"
        IsAdministrator = (Test-IsAdministrator)
        RequestedAdapter = $AdapterName
        Services = @(Get-Service Dhcp, Dnscache -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType)
        Adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed, ifIndex)
        IPv4Interfaces = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, Dhcp, ConnectionState, NlMtu, InterfaceMetric)
        IPv4Addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, IPAddress, PrefixLength, AddressState, PrefixOrigin, SuffixOrigin)
        DnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, ServerAddresses)
        DefaultRoutes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, NextHop, RouteMetric, State)
    }

    $path = Join-Path $OutputPath "$Stage.json"
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Log "Saved $Stage state to $path." 'SUCCESS'
}

function Save-Backups {
    Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Select-Object InterfaceAlias, InterfaceIndex, IPv4Address, IPv4DefaultGateway, DNSServer |
        Export-Clixml -LiteralPath (Join-Path $BackupPath 'ip-configuration.clixml')

    Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
        Export-Csv -LiteralPath (Join-Path $BackupPath 'dns-server-addresses.csv') -NoTypeInformation -Encoding UTF8

    Get-NetIPInterface -ErrorAction SilentlyContinue |
        Export-Csv -LiteralPath (Join-Path $BackupPath 'ip-interfaces.csv') -NoTypeInformation -Encoding UTF8
}

function Invoke-FlushDns {
    if (-not (Confirm-Action 'Flush the Windows DNS resolver cache?')) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would flush the DNS resolver cache.' 'DRYRUN'
        return
    }

    if (Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) {
        Clear-DnsClientCache
    } else {
        & ipconfig.exe /flushdns | Out-Null
    }
    Write-Log 'DNS resolver cache flushed.' 'SUCCESS'
}

function Invoke-RegisterDns {
    Require-Administrator
    if (-not (Confirm-Action 'Register this computer and its adapters with configured DNS servers?')) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would run Register-DnsClient.' 'DRYRUN'
        return
    }

    if (Get-Command Register-DnsClient -ErrorAction SilentlyContinue) {
        Register-DnsClient
    } else {
        & ipconfig.exe /registerdns 2>&1 | Add-Content -LiteralPath $LogPath
        if ($LASTEXITCODE -ne 0) { throw 'DNS registration failed.' }
    }
    Write-Log 'DNS registration was requested successfully.' 'SUCCESS'
}

function Invoke-RestartClientServices {
    Require-Administrator
    if (-not (Confirm-Action 'Restart DHCP Client and ensure DNS Client is running? Connectivity may briefly drop.')) { throw 'User cancelled.' }

    if ($DryRun) {
        Write-Log 'Would restart DHCP Client and start DNS Client if stopped.' 'DRYRUN'
        return
    }

    $dhcp = Get-Service -Name Dhcp -ErrorAction Stop
    if ($dhcp.Status -eq 'Running') {
        Restart-Service -Name Dhcp -Force -ErrorAction Stop
    } else {
        Start-Service -Name Dhcp -ErrorAction Stop
    }
    Write-Log 'DHCP Client service is running.' 'SUCCESS'

    $dns = Get-Service -Name Dnscache -ErrorAction Stop
    if ($dns.Status -ne 'Running') {
        Start-Service -Name Dnscache -ErrorAction Stop
        Write-Log 'DNS Client service was started.' 'SUCCESS'
    } else {
        Write-Log 'DNS Client service was already running.' 'INFO'
    }
}

function Invoke-RenewDhcp {
    Require-Administrator
    $adapter = Get-SelectedAdapter
    $ipInterface = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($ipInterface -and $ipInterface.Dhcp -ne 'Enabled') {
        throw "Adapter '$AdapterName' is not configured for DHCP. The tool will not overwrite static IPv4 settings."
    }

    if (-not (Confirm-Action "Release and renew DHCP for '$AdapterName'? Connectivity will be interrupted.")) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log "Would release and renew DHCP for '$AdapterName'." 'DRYRUN'
        return
    }

    & ipconfig.exe /release "$AdapterName" 2>&1 | Add-Content -LiteralPath $LogPath
    & ipconfig.exe /renew "$AdapterName" 2>&1 | Add-Content -LiteralPath $LogPath
    if ($LASTEXITCODE -ne 0) { throw "DHCP renewal failed for '$AdapterName'." }

    Start-Sleep -Seconds 3
    $address = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '169.254.*' } |
        Select-Object -First 1
    if (-not $address) { throw "Adapter '$AdapterName' did not receive a usable IPv4 address." }
    Write-Log "DHCP renewed for '$AdapterName'. Address: $($address.IPAddress)." 'SUCCESS'
}

function Invoke-RestartAdapter {
    Require-Administrator
    $adapter = Get-SelectedAdapter
    if (-not (Confirm-Action "Restart adapter '$AdapterName'? Connectivity will be interrupted.")) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log "Would restart adapter '$AdapterName'." 'DRYRUN'
        return
    }

    Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
    Start-Sleep -Seconds 4
    $after = Get-NetAdapter -Name $adapter.Name -ErrorAction Stop
    if ($after.Status -eq 'Disabled') { throw "Adapter '$AdapterName' remained disabled." }
    Write-Log "Restarted adapter '$AdapterName'. Current status: $($after.Status)." 'SUCCESS'
}

function Invoke-SetAutomaticDns {
    Require-Administrator
    $adapter = Get-SelectedAdapter
    $current = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop
    $current | Export-Clixml -LiteralPath (Join-Path $BackupPath "dns-$($adapter.ifIndex)-before.clixml")

    if (-not (Confirm-Action "Reset IPv4 DNS servers on '$AdapterName' to automatic/DHCP assignment?" -HighImpact)) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log "Would reset DNS server addresses on '$AdapterName'." 'DRYRUN'
        return
    }

    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction Stop
    Write-Log "DNS server assignment on '$AdapterName' was reset to automatic." 'SUCCESS'
}

function Invoke-ResetNetworkStack {
    Require-Administrator
    if (-not (Confirm-Action 'Reset Winsock and TCP/IP? A Windows restart is required.' -HighImpact)) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would reset Winsock and TCP/IP. A restart would be required.' 'DRYRUN'
        return
    }

    $ipResetLog = Join-Path $OutputPath 'netsh-ip-reset.log'
    & netsh.exe winsock reset 2>&1 | Add-Content -LiteralPath $LogPath
    if ($LASTEXITCODE -ne 0) { throw 'Winsock reset failed.' }
    & netsh.exe int ip reset $ipResetLog 2>&1 | Add-Content -LiteralPath $LogPath
    if ($LASTEXITCODE -ne 0) { throw 'TCP/IP reset failed.' }

    $script:RebootRequired = $true
    Write-Log 'Winsock and TCP/IP reset completed. Restart Windows before final validation.' 'SUCCESS'
}

function Invoke-SafeRepairSet {
    Invoke-FlushDns
    Invoke-RegisterDns
    Invoke-RestartClientServices
    if (-not [string]::IsNullOrWhiteSpace($AdapterName)) {
        Invoke-RenewDhcp
    }
}

Write-Log "DNS DHCP Repair Toolkit $ScriptVersion started. DryRun=$DryRun"
Save-State -Stage 'before'
Save-Backups

$hasRepair = $RepairAllSafe -or $FlushDns -or $RegisterDns -or $RestartClientServices -or $RenewDhcp -or $RestartAdapter -or $SetAutomaticDns -or $ResetWinsockTcpIp
if (-not $hasRepair) {
    Write-Log 'Diagnostic-only run completed. No repair switch was selected.' 'SUCCESS'
    Save-State -Stage 'after'
    exit 0
}

try {
    if ($RepairAllSafe)          { Invoke-SafeRepairSet }
    if ($FlushDns)               { Invoke-FlushDns }
    if ($RegisterDns)            { Invoke-RegisterDns }
    if ($RestartClientServices)  { Invoke-RestartClientServices }
    if ($RenewDhcp)              { Invoke-RenewDhcp }
    if ($RestartAdapter)         { Invoke-RestartAdapter }
    if ($SetAutomaticDns)        { Invoke-SetAutomaticDns }
    if ($ResetWinsockTcpIp)      { Invoke-ResetNetworkStack }
} catch {
    if ($_.Exception.Message -eq 'User cancelled.') {
        $ExitCode = 10
        Write-Log 'Repair cancelled by the user.' 'WARN'
    } elseif ($_.Exception.Message -match 'elevated') {
        $ExitCode = 4
        Write-Log $_.Exception.Message 'ERROR'
    } else {
        $ExitCode = 20
        Write-Log $_.Exception.Message 'ERROR'
    }
} finally {
    try { Save-State -Stage 'after' } catch { Write-Log "Post-repair snapshot failed: $($_.Exception.Message)" 'WARN' }
}

if ($RebootRequired) {
    Write-Log 'REBOOT REQUIRED: the network stack reset is not complete until Windows restarts.' 'WARN'
}
if ($ExitCode -eq 0) {
    Write-Log "Completed successfully. Output: $OutputPath" 'SUCCESS'
} else {
    Write-Log "Completed with exit code $ExitCode. Output: $OutputPath" 'ERROR'
}
exit $ExitCode
