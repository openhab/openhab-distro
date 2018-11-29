@ECHO off
SETLOCAL

IF "%1"=="?" GOTO printArgs
IF "%1"=="\?" GOTO printArgs
IF "%1"=="/?" GOTO printArgs

IF NOT [%~2]==[] IF NOT "%~2"=="true" IF NOT "%~2"=="false" GOTO printArgs

SET uargs=
IF NOT [%1]==[] ( SET uargs=%uargs% -OHVersion %~1% )

SET snapshot=False
IF "%~2"=="true" SET snapshot=True

CD %~dp0
powershell -ExecutionPolicy Bypass -command "& { . .\update.ps1; Update-openHAB %uargs% -Snapshot $%snapshot% }"
SET LEVEL=%ERRORLEVEL%

if %LEVEL% LSS 0 (
    PAUSE
    EXIT /B %LEVEL%
)
EXIT /B 0

:printArgs
ECHO Usage: update.bat {OHVersion} [{Snapshot}]
ECHO OHVersion (required) - The version you want to update (2.3, 2.4, etc)
ECHO Snapshot  (optional) - "true" if snapshot, "false" or not specified for stable
ECHO.
ECHO Example to update to OH version 2.3.0 stable:
ECHO    update.bat 2.3.0
ECHO.
ECHO Example to update to OH version 2.3.0 snapshot:
ECHO    update.bat 2.3.0 true
ECHO.
EXIT /B -1
