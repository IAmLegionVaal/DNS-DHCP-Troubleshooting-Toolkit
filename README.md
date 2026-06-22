# DNS and DHCP Troubleshooting and Repair Toolkit

PowerShell tooling for Windows DNS and DHCP diagnostics plus guarded local repair, created by **Dewald Pretorius**.

## Files

- `DNS_DHCP_Troubleshooting_Toolkit.ps1` — read-only IP, DNS, gateway, DHCP and APIPA reporting.
- `DNS_DHCP_Repair_Toolkit.ps1` — guarded DNS, DHCP, adapter and network-stack repairs.
- `Launch_DNS_DHCP_Repair.bat` — interactive technician menu.

## Diagnostic default

Running the repair script without a repair switch collects current adapter, IPv4, DNS, route and client-service state without changing the workstation.

```powershell
.\DNS_DHCP_Repair_Toolkit.ps1
```

## Safe repair set

The safe set:

1. Flushes the DNS resolver cache.
2. Registers the computer with configured DNS servers.
3. Restarts DHCP Client and ensures DNS Client is running.
4. Renews DHCP on one selected adapter when `-AdapterName` is supplied.

```powershell
.\DNS_DHCP_Repair_Toolkit.ps1 -RepairAllSafe -AdapterName "Wi-Fi" -DryRun
```

## Individual repairs

```powershell
.\DNS_DHCP_Repair_Toolkit.ps1 -FlushDns
.\DNS_DHCP_Repair_Toolkit.ps1 -RegisterDns
.\DNS_DHCP_Repair_Toolkit.ps1 -RestartClientServices
.\DNS_DHCP_Repair_Toolkit.ps1 -RenewDhcp -AdapterName "Ethernet"
.\DNS_DHCP_Repair_Toolkit.ps1 -RestartAdapter -AdapterName "Wi-Fi"
.\DNS_DHCP_Repair_Toolkit.ps1 -SetAutomaticDns -AdapterName "Wi-Fi"
.\DNS_DHCP_Repair_Toolkit.ps1 -ResetWinsockTcpIp
```

## Repair behaviour

- DHCP renewal is refused when the selected adapter uses static IPv4 addressing.
- Automatic DNS reset applies only to the explicitly selected adapter.
- Current DNS server configuration is exported before automatic DNS reset.
- Winsock and TCP/IP reset is a high-impact action and requires a restart.
- APIPA recovery is handled through selected-adapter DHCP renewal and post-action address verification.

The script does not automatically replace static IP addresses, gateways or manually assigned DNS servers.

## Logs, evidence and backups

Each run creates a timestamped desktop folder containing:

- `before.json` and `after.json`
- `repair.log`
- IP configuration backup
- DNS server-address backup
- IP-interface backup
- Network-stack reset log when selected

## Safety

- Diagnosis is the default.
- `-DryRun` previews repairs.
- Standard repairs require typing `YES` unless `-Yes` is supplied.
- Automatic DNS and network-stack reset require typing `REPAIR`.
- DHCP, adapter, service and stack repairs normally require elevation.
- Connectivity can briefly drop during service, DHCP and adapter actions.
- Resetting DNS to automatic can remove intentionally configured DNS servers; review the backup first.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including diagnosis or dry-run |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | Repair action or validation failed |

## Interactive launcher

Double-click:

```text
Launch_DNS_DHCP_Repair.bat
```

## Validation status

Tested successfully by the author on his own Windows machines. The documented DNS, DHCP, adapter and network-stack diagnostic and repair workflows worked as intended on those systems.

Results may vary with the Windows build, adapter hardware and driver, DHCP server, DNS infrastructure, static addressing, VPN software, security policy, network topology and user-specific configuration. Use `-DryRun` before applying repairs on a new network or device.
