@ECHO off
SETLOCAL

IF "%1"=="?" GOTO printArgs
IF "%1"=="\?" GOTO printArgs
IF "%1"=="/?" GOTO printArgs

SET uargs=
IF NOT [%1]==[] ( SET uargs=%uargs% -OHVersion %~1% )

CD %~dp0
powershell -ExecutionPolicy Bypass -command "& { . .\update.ps1; Update-openHAB %uargs% }"
SET LEVEL=%ERRORLEVEL%

if %LEVEL% LSS 0 (
    PAUSE
    EXIT /B %LEVEL%
)
EXIT /B 0

:printArgs
ECHO Usage: update.bat {OHVersion}
ECHO OHVersion (required) - The version you want to update (2.3, 2.4, etc)
ECHO.
ECHO Example to update to OH version 2.3.0 stable:
ECHO    update.bat 2.3.0
ECHO.
ECHO Example to update to OH version 2.3.0 snapshot:
ECHO    update.bat 2.3.0-SNAPSHOT
ECHO.
ECHO Example to update to OH version 2.4.0 milestone:
ECHO    update.bat 2.4.0-M6
ECHO.
EXIT /B -1
