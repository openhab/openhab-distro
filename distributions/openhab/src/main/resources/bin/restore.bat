@ECHO off
SETLOCAL

IF NOT [%~4]==[] IF NOT "%~4"=="true" IF NOT "%~4"=="false" GOTO printArgs

SET autoConfirm=False
IF "%~4"=="true" SET autoConfirm=True
powershell -command "& { . .\restore.ps1; Restore-openHAB -OHDirectory %~1 -OHBackups %~2 -FileName %~3 -AutoConfirm $%autoConfirm% }"
EXIT /B 0

:printArgs
ECHO Usage: restore.bat {OHDirectory} {OHBackups} {FileName} {AutoConfirm}
ECHO OHDirectory (optional) - The openHAB distribution directory
ECHO OHBackups   (optional) - The directory where backups are stored
ECHO FileName    (optional) - The backup file name (found in OHBackups)
ECHO AutoConfrim (optional) - "true" to automatically confirm restoration, "false" otherwise
ECHO.
ECHO Example to restore openHAB from the latest backup in the default locations
ECHO    restore.bat
ECHO.
ECHO Example to restore openHAB from the "backup.zip" found in "c:\openhab2\backups" with auto confirming:
ECHO    update.bat "c:\openhab2" "c:\openhab2\backups" "backup.zip" true 
ECHO.
EXIT /B -1
