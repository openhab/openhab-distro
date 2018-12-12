@ECHO off
SETLOCAL

IF "%1"=="?" GOTO printArgs
IF "%1"=="\?" GOTO printArgs
IF "%1"=="/?" GOTO printArgs

SET bargs=

IF NOT [%1]==[] ( SET bargs=%bargs% -MaxFiles %~1% )
IF NOT [%2]==[] ( SET bargs=%bargs% -OHDirectory %~2% )
IF NOT [%3]==[] ( SET bargs=%bargs% -OHBackups %~3% )
IF NOT [%4]==[] ( SET bargs=%bargs% -FileName %~4% )

CD %~dp0
powershell -ExecutionPolicy Bypass -command "&{. .\backup.ps1; Backup-openHAB %bargs% }" 
SET LEVEL=%ERRORLEVEL%

if %LEVEL% LSS 0 (
    PAUSE
    EXIT /B %LEVEL%
)
EXIT /B 0

:printArgs
ECHO Usage: backup.bat {MaxFiles} {OHDirectory} {OHBackups} {FileName}
ECHO MaxFiles    (optional) - The maximum number of backups to keep (specify 0 for no maximum)
ECHO OHDirectory (optional) - The openHAB distribution directory
ECHO OHBackups   (optional) - The directory where backups are stored
ECHO FileName    (optional) - The backup file name (found in OHBackups)
ECHO.
ECHO Example to backup openHAB to the default locations
ECHO    backup.bat
ECHO.
ECHO Example to backup openHAB to "backup.zip" in "c:\openhab2\backups" keeping at most 10 backups:
ECHO    backup.bat 10 "c:\openhab2" "c:\openhab2\backups" "backup.zip" 
ECHO.
EXIT /B -1
