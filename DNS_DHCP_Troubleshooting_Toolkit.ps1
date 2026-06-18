#requires -Version 5.1
<#
.SYNOPSIS
    DNS DHCP Troubleshooting Toolkit.
.DESCRIPTION
    Diagnostic-only DNS and DHCP context checker for Windows support.
#>
[CmdletBinding()]
param([string]$HostName='www.microsoft.com',[string]$OutputPath)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DNS_DHCP_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
function New-Check { param($Category,$Name,$Status,$Value,$Recommendation) [PSCustomObject]@{Category=$Category;Name=$Name;Status=$Status;Value=$Value;Recommendation=$Recommendation} }
$checks = @()
$configs = Get-NetIPConfiguration
foreach($cfg in $configs){
    $ipv4 = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
    $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
    $dns = ($cfg.DNSServer.ServerAddresses -join ', ')
    $status = if($ipv4 -like '169.254.*'){'Warning'}elseif($ipv4){'OK'}else{'Info'}
    $checks += New-Check 'IP Configuration' $cfg.InterfaceAlias $status "IPv4=$ipv4; Gateway=$gw; DNS=$dns" 'Review DHCP, gateway, and DNS assignment.'
    if($gw){ $ping = Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue; $checks += New-Check 'Gateway' $gw ($(if($ping){'OK'}else{'Warning'})) $ping 'Gateway reachability check.' }
}
foreach($name in @($HostName,'login.microsoftonline.com','www.microsoft.com') | Select-Object -Unique){
    try { $records = Resolve-DnsName $name -ErrorAction Stop; $ips = ($records | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress -Unique) -join ', '; $checks += New-Check 'DNS' "Resolve $name" 'OK' $ips 'DNS resolution succeeded.' } catch { $checks += New-Check 'DNS' "Resolve $name" 'Warning' $_.Exception.Message 'Review DNS servers, suffixes, VPN, or filtering.' }
}
try { $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias,ServerAddresses; $dnsServers | Export-Csv (Join-Path $OutputPath "dns_servers_$RunStamp.csv") -NoTypeInformation -Encoding UTF8 } catch {}
$checks | Export-Csv (Join-Path $OutputPath "dns_dhcp_checks_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$checks | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputPath "dns_dhcp_checks_$RunStamp.json") -Encoding UTF8
$checks | ConvertTo-Html -Title 'DNS DHCP Troubleshooting' -PreContent "<h1>DNS DHCP Troubleshooting - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>" | Set-Content (Join-Path $OutputPath "dns_dhcp_report_$RunStamp.html") -Encoding UTF8
$checks | Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
