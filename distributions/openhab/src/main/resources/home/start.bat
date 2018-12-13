@echo off

echo Launching the openHAB runtime...

setlocal
set DIRNAME=%~dp0%

IF [%OPENHAB_RUNTIME%]==[] (
	set RUNTIME=%DIRNAME%\runtime
) ELSE (
	set RUNTIME=%OPENHAB_RUNTIME%
)
"%RUNTIME%\bin\karaf.bat" %*
