# DNS DHCP Troubleshooting Toolkit

A diagnostic PowerShell toolkit for DNS and DHCP support checks.

## Features

- IP configuration summary
- DNS server assignment summary
- DNS resolution tests
- Gateway reachability checks
- DHCP-related adapter context
- APIPA detection
- CSV, JSON, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DNS_DHCP_Troubleshooting_Toolkit.ps1
```

Use a custom hostname:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DNS_DHCP_Troubleshooting_Toolkit.ps1 -HostName example.com
```

## Safety

Diagnostic-only. It does not change DNS, IP, or DHCP settings.

## Suggested topics

```text
powershell
dns
dhcp
networking
windows
helpdesk
it-support
troubleshooting
```
