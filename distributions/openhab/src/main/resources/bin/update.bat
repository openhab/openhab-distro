@ECHO off
SETLOCAL

IF [%~1]==[] GOTO printArgs
IF NOT [%~2]==[] IF NOT "%~2"=="true" IF NOT "%~2"=="false" GOTO printArgs

SET snapshot=False
if "%~2"=="true" SET snapshot=True

powershell -command "& { . .\update.ps1; Update-openHAB -OHVersion %~1 -Snapshot $%snapshot% }"
EXIT /B 0

:printArgs
ECHO Usage: update.bat {OHVersion} [{Snapshot}]
ECHO OHVersion (required) - The version you want to update (2.3, 2.4, etc)
ECHO Snapshot  (optional) - "true" if snapshot, "false" or not specified for stable
ECHO.
ECHO Example to update to OH version 2.3 stable:
ECHO    update.bat 2.3
ECHO.
ECHO Example to update to OH version 2.3 snapshot:
ECHO    update.bat 2.3 true
ECHO.
EXIT /B -1
