@echo off
setlocal
cd /d "%~dp0"

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

if "%CHOICE%"=="1" set ARGS=&goto run
if "%CHOICE%"=="2" goto safe
if "%CHOICE%"=="3" set ARGS=-FlushDns&goto run
if "%CHOICE%"=="4" set ARGS=-RegisterDns&goto run
if "%CHOICE%"=="5" set ARGS=-RestartClientServices&goto run
if "%CHOICE%"=="6" goto dhcp
if "%CHOICE%"=="7" goto adapter
if "%CHOICE%"=="8" goto autodns
if "%CHOICE%"=="9" set ARGS=-ResetWinsockTcpIp&goto run
if "%CHOICE%"=="0" goto end
goto menu

:safe
set /p ADAPTER=Adapter name for DHCP renewal (leave blank to skip renewal): 
set ARGS=-RepairAllSafe
if not "%ADAPTER%"=="" set ARGS=%ARGS% -AdapterName "%ADAPTER%"
goto run

:dhcp
set /p ADAPTER=Adapter name: 
set ARGS=-RenewDhcp -AdapterName "%ADAPTER%"
goto run

:adapter
set /p ADAPTER=Adapter name: 
set ARGS=-RestartAdapter -AdapterName "%ADAPTER%"
goto run

:autodns
set /p ADAPTER=Adapter name: 
set ARGS=-SetAutomaticDns -AdapterName "%ADAPTER%"
goto run

:run
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0DNS_DHCP_Repair_Toolkit.ps1' -ErrorAction SilentlyContinue; & '%~dp0DNS_DHCP_Repair_Toolkit.ps1' %ARGS%"
echo.
pause
goto menu

:end
endlocal
