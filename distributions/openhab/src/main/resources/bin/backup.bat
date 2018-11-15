@ECHO off
SETLOCAL

powershell -command "& { . .\backup.ps1; Backup-openHAB -OHDirectory %~1 -OHBackups %~2 -FileName %~3 }"
EXIT /B 0

:printArgs
ECHO Usage: backup.bat {OHDirectory} {OHBackups} {FileName}
ECHO OHDirectory (optional) - The openHAB distribution directory
ECHO OHBackups   (optional) - The directory where backups are stored
ECHO FileName    (optional) - The backup file name (found in OHBackups)
ECHO.
ECHO Example to backup openHAB to the default locations
ECHO    backup.bat
ECHO.
ECHO Example to backup openHAB to "backup.zip" in "c:\openhab2\backups":
ECHO    update.bat "c:\openhab2" "c:\openhab2\backups" "backup.zip" 
ECHO.
EXIT /B -1
