@echo off
setlocal EnableDelayedExpansion

:: ----------------------------------------------------------
:: 1. Check & Request Administrative Privileges
:: ----------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~dpnx0' -Verb RunAs"
    exit /b
)

title CyberPatriot Windows 11 Hardening Script
color 0b
echo =========================================================
echo       CyberPatriot Windows 11 Hardening Script
echo =========================================================
echo.

:: ----------------------------------------------------------
:: 2. Password & Account Lockout Policies
:: ----------------------------------------------------------
echo [+] Applying local password and lockout policies...
net accounts /minpwlen:12
net accounts /maxpwage:30
net accounts /minpwage:1
net accounts /uniquepw:5
net accounts /lockoutthreshold:5
net accounts /lockoutduration:30
net accounts /lockoutwindow:30

:: Disable Guest account
net user Guest /active:no >nul 2>&1
echo [OK] Account policies applied.

:: ----------------------------------------------------------
:: 3. Windows Firewall Configuration
:: ----------------------------------------------------------
echo.
echo [+] Enabling Windows Firewall across all profiles...
netsh advfirewall set allprofiles state on
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
echo [OK] Firewall enabled and set to block inbound.

:: ----------------------------------------------------------
:: 4. Audit Policies
:: ----------------------------------------------------------
echo.
echo [+] Enabling system auditing (Success/Failure)...
auditpol /set /category:"Account Logon" /success:enable /failure:enable >nul
auditpol /set /category:"Account Management" /success:enable /failure:enable >nul
auditpol /set /category:"Detailed Tracking" /failure:enable >nul
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable >nul
auditpol /set /category:"Policy Change" /success:enable /failure:enable >nul
auditpol /set /category:"Privilege Use" /failure:enable >nul
auditpol /set /category:"System" /success:enable /failure:enable >nul
auditpol /set /subcategory:"Process Creation" /success:enable >nul
echo [OK] Auditing configured.

:: ----------------------------------------------------------
:: 5. Registry Hardening (UAC, LSA, SmartScreen, AutoRun)
:: ----------------------------------------------------------
echo.
echo [+] Applying Registry security policies...

:: Enable UAC & Secure Desktop
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f >nul

:: Restrict Anonymous Enumeration & Protect LSA
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymousSAM /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 1 /f >nul

:: Disable AutoPlay / AutoRun
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul

:: Disable SMBv1
powershell -Command "Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force" >nul 2>&1
echo [OK] Registry baselines set.

:: ----------------------------------------------------------
:: 6. Insecure & Vulnerable Services
:: ----------------------------------------------------------
echo.
echo [+] Disabling common dangerous services...
for %%s in (RemoteRegistry TlntSvr SNMP SessionEnv TermService FTPSVC SharedAccess) do (
    sc query %%s >nul 2>&1
    if !errorlevel! equ 0 (
        sc stop %%s >nul 2>&1
        sc config %%s start= disabled >nul 2>&1
        echo   [-] Disabled service: %%s
    )
)
echo [OK] Services updated.

:: ----------------------------------------------------------
:: 7. Windows Defender & Realtime Protection
:: ----------------------------------------------------------
echo.
echo [+] Updating Defender configuration...
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false -DisableScriptScanning $false" >nul 2>&1
echo [OK] Windows Defender enabled.

:: ----------------------------------------------------------
:: 8. User & Administrator Audit
:: ----------------------------------------------------------
echo.
echo =========================================================
echo                  USER ACCOUNT AUDIT
echo =========================================================
echo Local Users:
net user
echo.
echo Members of Administrators Group:
net localgroup administrators
echo =========================================================

:: ----------------------------------------------------------
:: 9. Prohibited Media Check (Report Only)
:: ----------------------------------------------------------
echo.
echo [+] Scanning C:\Users for media files (mp3, mp4, avi, mov)...
dir /s /b C:\Users\*.mp3 C:\Users\*.mp4 C:\Users\*.avi C:\Users\*.mov 2>nul
if %errorlevel% neq 0 (
    echo   [OK] No common audio/video media files detected.
)

echo.
echo =========================================================
echo [DONE] Baseline complete. 
echo Verify authorized users above against your scenario README!
echo =========================================================
pause
