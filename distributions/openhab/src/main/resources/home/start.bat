@echo off

echo Launching the openHAB runtime...

setlocal
set DIRNAME=%~dp0%
"%DIRNAME%runtime\bin\karaf.bat" %*
