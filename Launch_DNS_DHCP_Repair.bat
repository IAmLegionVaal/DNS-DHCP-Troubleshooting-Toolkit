@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0DNS_DHCP_Repair_Toolkit.ps1' -ErrorAction SilentlyContinue"

:menu
cls
echo ============================================================
echo   DNS AND DHCP REPAIR TOOLKIT
echo ============================================================
echo   1. Diagnose only
echo   2. Run safe repair set
echo   3. Flush DNS cache
echo   4. Register DNS records
echo   5. Restart DHCP and DNS client services
echo   6. Renew DHCP on a selected adapter
echo   7. Restart a selected adapter
echo   8. Reset selected adapter DNS to automatic
echo   9. Reset Winsock and TCP-IP
echo   0. Exit
echo ============================================================
set /p CHOICE=Select an option: 

if "%CHOICE%"=="1" goto diagnose
if "%CHOICE%"=="2" goto safe
if "%CHOICE%"=="3" goto flushdns
if "%CHOICE%"=="4" goto registerdns
if "%CHOICE%"=="5" goto services
if "%CHOICE%"=="6" goto dhcp
if "%CHOICE%"=="7" goto adapter
if "%CHOICE%"=="8" goto autodns
if "%CHOICE%"=="9" goto stack
if "%CHOICE%"=="0" goto end
goto menu

:diagnose
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1"
goto complete

:safe
set /p ADAPTER=Adapter name for DHCP renewal (leave blank to skip renewal): 
if "%ADAPTER%"=="" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RepairAllSafe
if not "%ADAPTER%"=="" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RepairAllSafe -AdapterName "%ADAPTER%"
goto complete

:flushdns
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -FlushDns
goto complete

:registerdns
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RegisterDns
goto complete

:services
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RestartClientServices
goto complete

:dhcp
set /p ADAPTER=Adapter name: 
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RenewDhcp -AdapterName "%ADAPTER%"
goto complete

:adapter
set /p ADAPTER=Adapter name: 
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -RestartAdapter -AdapterName "%ADAPTER%"
goto complete

:autodns
set /p ADAPTER=Adapter name: 
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -SetAutomaticDns -AdapterName "%ADAPTER%"
goto complete

:stack
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0DNS_DHCP_Repair_Toolkit.ps1" -ResetWinsockTcpIp
goto complete

:complete
echo.
pause
goto menu

:end
endlocal
