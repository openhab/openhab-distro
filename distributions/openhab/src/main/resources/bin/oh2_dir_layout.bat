rem DIRNAME is the directory of karaf, setenv, etc.
CALL :removeSpacesFromPath "%DIRNAME%..\.."

set OPENHAB_HOME=%RETVAL%

:check_conf
IF NOT [%OPENHAB_CONF%] == [] GOTO :conf_set
set OPENHAB_CONF=%OPENHAB_HOME%\conf
:conf_set

:check_runtime
IF NOT [%OPENHAB_RUNTIME%] == [] GOTO :runtime_set
set OPENHAB_RUNTIME=%OPENHAB_HOME%\runtime
:runtime_set

:check_userdata
IF NOT [%OPENHAB_USERDATA%] == [] GOTO :userdata_set
set OPENHAB_USERDATA=%OPENHAB_HOME%\userdata
:userdata_set

:check_logs
IF NOT [%OPENHAB_LOGDIR%] == [] GOTO :logs_set
set OPENHAB_LOGDIR=%OPENHAB_USERDATA%\logs
:logs_set

rem Make sure the tmp folder exists as Karaf requires it
IF NOT EXIST "%OPENHAB_USERDATA%\tmp" (
  mkdir "%OPENHAB_USERDATA%\tmp"
)

set KARAF_HOME=%OPENHAB_RUNTIME%
set KARAF_DATA=%OPENHAB_USERDATA%
set KARAF_BASE=%OPENHAB_USERDATA%
set KARAF_ETC=%OPENHAB_USERDATA%\etc

EXIT /B

:removeSpacesFromPath
	SET RETVAL=%~s1
	EXIT /B
