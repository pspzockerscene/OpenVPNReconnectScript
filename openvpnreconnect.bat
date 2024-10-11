@ECHO OFF
REM http://steve-jansen.github.io/guides/windows-batch-scripting/part-2-variables.html
SETLOCAL ENABLEEXTENSIONS
SETLOCAL enableDelayedExpansion

title OpenVPN reconnect script v.1.5 by JDownloader Team (additional thanks goes to sanchezvictor)
REM Thanks to forum user "sanchezvictor" for initial version of this script: https://board.jdownloader.org/showthread.php?t=83875

REM Set your OpenVPN installation directory here otherwise this script won't do anything.
SET "openvpndir=C:\Program Files\OpenVPN"

REM Set this to 1 to enable debug messages
SET /A debug=0
REM Set this to 1 to skip some wait times for testing
SET /A skip_non_important_sleep_statements=0

REM Path were our script gets executed in
SET parent=%~dp0
SET /a ERROR_GENERIC=1
SET /a ERROR_FILE_MISSING=2

REM Users tend to break scripts so lets check for this as we got only one variable which the user is supposed to change.
if not defined openvpndir (
    cls & color 04
    echo You broke the script^^! Re-download it and don't mess up your OpenVPN installation path^^! & echo  Closing in some seconds...
    if %skip_non_important_sleep_statements% EQU 0 ping localhost -n 10>nul
    exit /B %ERROR_GENERIC%
)

if %debug% EQU 1 echo Script is located in: %parent%
if %debug% EQU 1 echo Script is executed in: %CD%

if not exist %openvpndir% if exist "openvpn.exe" (
	SET "openvpndir=%parent%.."
	echo Warning: Looks like given install path is wrong but script has been moved into OpenVPN install directory. Using this as 'openvpndir' path value instead:
	echo %openvpndir%
	if %skip_non_important_sleep_statements% EQU 0 (
		echo Continuing in some seconds...
		ping localhost -n 10>nul
	)
)

SET "openvpndir_config=%openvpndir%\config"
SET "openvpndir_bin=%openvpndir%\bin\openvpn-gui.exe"

if not exist "%openvpndir%" (
    cls & color 04
    echo Failed to locate OpenVPN installation in "%openvpndir%"^^! & echo Adjust your 'openvpndir' path in this script to fix this^^! & echo Closing in some seconds...
    ping localhost -n 20>nul
    exit /B %ERROR_FILE_MISSING%
)

REM Find config containing info about last used/blacklisted VPN configs
SET "pathConfig=%parent%openvpnreconnect_lastconfig.txt"
if %debug% EQU 1 echo pathConfig=%pathConfig%

SET "blacklistedConfig=NONE"
if exist "%pathConfig%"2>nul (
	if %debug% EQU 1 echo Found existing config file
	REM Put first line inside last config file into variable
	<"%pathConfig%" set /p blacklistedConfig=
	REM Alternative command but this one was blocking CMD and waiting for user to hit enter SET /p "blacklistedConfig=<%pathConfig%
	if %debug% EQU 1 echo Found existing config file ^-^> blacklisting last used config !blacklistedConfig!
)
if %debug% EQU 1 echo blacklistedConfig=%blacklistedConfig%


REM Count all of the users' config files and fine the position of our blacklisted config for this run
if %debug% EQU 1 echo Full list of users' VPN configs:
SET /A blacklistedConfigPosition=-1
SET numberofConfigs=0

FOR /f "tokens=1*delims=:" %%a IN (
 'dir /b /a-d "%openvpndir_config%\*.ovpn"^|findstr /n /i ".ovpn" '
 ) DO (
    if %debug% EQU 1 (
        echo [!numberofConfigs!] %%b
    )
    REM Create our "array"
    SET "configpath[!numberofConfigs!]=%%b"
	if "%%b"=="%blacklistedConfig%" SET /a "blacklistedConfigPosition=!numberofConfigs!"
	set /a numberofConfigs+=1
)

if exist "%pathConfig%" if %blacklistedConfigPosition% EQU -1 (
    echo WARNING: Last used config "%blacklistedConfig%" was not found. Either user has deleted it or something did not work as intended^^!
)

if %debug% EQU 1 echo Number of found .ovpn config files: %numberofConfigs%

if %numberofConfigs% EQU 0 (
    cls & color 04
    echo Failed to find any .ovpn config files in %openvpndir_config%^^! & echo Closing in some seconds...
    ping localhost -n 20>nul
    exit /B %ERROR_FILE_MISSING%
)

if %numberofConfigs% EQU 1 (
    color 04
    echo Warning: Only found 1 config^^! This way you might not be able to reliably use this script to change your IP multiple times^^! & echo Continuing in some seconds...
    if %skip_non_important_sleep_statements% EQU 0 ping localhost -n 10>nul
    REM Important! Prevent possible infinite loop when picking our random config later (edge case: user had multiple configs before but now only has one and this one was used last time.).
    SET /A blacklistedConfigPosition=-1
)

if %blacklistedConfigPosition% NEQ -1 (
    echo Avoiding last used config: [%blacklistedConfigPosition%] %blacklistedConfig%
)

REM Pick a number between 0 and (%numberofConfigs% - 1)
:GetNumber
set /a selection=%random% %% %numberofConfigs%
IF %selection% EQU %blacklistedConfigPosition% GOTO getnumber

REM set /a selection=0

SET "selectedConfigPath=!configpath[%selection%]!"
SET "filename=!configpath[%selection%]!"
echo Auto-selected config: [%selection%] %filename%

REM Write filename of last used VPN config file into textfile so we can work with it the next time this script gets executed.
REM @echo /p %filename% > "%pathConfig%"
REM Write to file without trailing space/newline: https://superuser.com/questions/446720/windows-7-batch-files-how-to-write-string-to-text-file-without-carriage-return
REM echo WTF %filename%moretext
REM echo |  set /P =%filename%> "%pathConfig%"
REM see https://stackoverflow.com/questions/19149305/echoing-to-a-file-results-in-spaces-in-batch

>"%pathConfig%" echo %filename%
if not exist "%pathConfig%" (
    color 04
    echo Warning: Failed to write to file %pathConfig% ^^! & echo Make sure to run this script below your user folder and/or place it in a folder below your user folder.
    echo In JDownloader, leave the 'Start in' field blank or set it to somewhere below your user folder e.g. C:\Users\%USERNAME%\someFolder.
    echo This script will run even without write permissions but it can happen that upon execution, the last used VPN location/config gets picked again which will cause the need for another retry and thus waste time.
    echo Continuing without write permissions in some seconds...
    ping localhost -n 10>nul
)

REM Change CMD color to signal the user that everything is alright.
color 0a
REM Kill OpenVPN if it's running
REM # https://stackoverflow.com/questions/162291/how-to-check-if-a-process-is-running-via-a-batch-script
SET /A killedProcess=0
QPROCESS "openvpn.exe" >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    taskkill.exe /F /IM openvpn.exe > nul
    SET /A killedProcess=1
)
QPROCESS "openvpn-gui.exe" >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    taskkill.exe /F /IM openvpn-gui.exe > nul
    SET /A killedProcess=1
)
if %killedProcess% EQU 1 (
    echo Killed OpenVPN processe^(s^) ^-^- ^> Waiting some seconds
    ping localhost -n 5 >nul
)

echo Connecting to VPN config: [%selection%] "%filename%"
REM This was my attempt to gracefully end the current VPN connection but that seems to be impossible like this.
REM start /b "" "%openvpndir_bin%" --silent_connection 1 --disconnect_all
start /b "" "%openvpndir_bin%" --silent_connection 1 --connect "%filename%"
echo Success^^! Your IP should change within the next few seconds^^!
REM If we don't do this, JDownloader might detect our non proxy VPN as new IP which would be wrong!
echo Closing in some seconds...
ping localhost -n 10 >nul

GOTO :EOF
