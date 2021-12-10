@echo off
rem
rem
rem    Licensed to the Apache Software Foundation (ASF) under one or more
rem    contributor license agreements.  See the NOTICE file distributed with
rem    this work for additional information regarding copyright ownership.
rem    The ASF licenses this file to You under the Apache License, Version 2.0
rem    (the "License"); you may not use this file except in compliance with
rem    the License.  You may obtain a copy of the License at
rem
rem       http://www.apache.org/licenses/LICENSE-2.0
rem
rem    Unless required by applicable law or agreed to in writing, software
rem    distributed under the License is distributed on an "AS IS" BASIS,
rem    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem    See the License for the specific language governing permissions and
rem    limitations under the License.
rem

rem
rem handle specific scripts; the SCRIPT_NAME is exactly the name of the Karaf
rem script; for example karaf.bat, start.bat, stop.bat, admin.bat, client.bat, ...
rem
rem if "%KARAF_SCRIPT%" == "SCRIPT_NAME" (
rem   Actions go here...
rem )

rem
rem general settings which should be applied for all scripts go here; please keep
rem in mind that it is possible that scripts might be executed more than once, e.g.
rem in example of the start script where the start script is executed first and the
rem karaf script afterwards.
rem

rem
rem The following section shows the possible configuration options for the default 
rem karaf scripts
rem
rem Window name of the windows console
rem SET KARAF_TITLE
rem Location of Java installation
rem SET JAVA_HOME
rem Minimum memory for the JVM
rem SET JAVA_MIN_MEM
rem Maximum memory for the JVM
rem SET JAVA_MAX_MEM
rem Minimum perm memory for the JVM
rem SET JAVA_PERM_MEM
rem Maximum perm memory for the JVM
rem SET JAVA_MAX_PERM_MEM
rem Additional JVM options
rem SET EXTRA_JAVA_OPTS 
rem Karaf home folder
rem SET KARAF_HOME
rem Karaf data folder
rem SET KARAF_DATA
rem Karaf base folder
rem SET KARAF_BASE
rem Karaf etc folder
rem SET KARAF_ETC
rem First citizen Karaf options
rem SET KARAF_SYSTEM_OPTS
rem Additional available Karaf options
rem SET KARAF_OPTS
rem Enable debug mode
rem SET KARAF_DEBUG

:: Use openHAB directory layout
call "%DIRNAME%oh_dir_layout.bat"

:: set listen address for HTTP(S) server
:check_http_address
IF NOT [%OPENHAB_HTTP_ADDRESS%] == [] GOTO :http_address_set
set HTTP_ADDRESS=0.0.0.0
goto :http_address_done

:http_address_set
set HTTP_ADDRESS=%OPENHAB_HTTP_ADDRESS%
goto :http_address_done

:http_address_done

:: set ports for HTTP(S) server
:check_http_port
IF NOT [%OPENHAB_HTTP_PORT%] == [] GOTO :http_port_set
set HTTP_PORT=8080
goto :http_port_done

:http_port_set
set HTTP_PORT=%OPENHAB_HTTP_PORT%
goto :http_port_done

:http_port_done

:check_https_port
IF NOT [%OPENHAB_HTTPS_PORT%] == [] GOTO :https_port_set
set HTTPS_PORT=8443
goto :https_port_done

:https_port_set
set HTTPS_PORT=%OPENHAB_HTTPS_PORT%
goto :https_port_done

:https_port_done

:: set the Java debug port with a wildcard, so that it is bound to all interfaces
:: (java/karaf otherwise only binds it to localhost)
:check_debug_port
IF NOT [%OPENHAB_JAVA_DEBUG_PORT%] == [] GOTO :debug_port_set
set JAVA_DEBUG_PORT=*:5005
goto :debug_port_done

:debug_port_set
set JAVA_DEBUG_PORT=%OPENHAB_JAVA_DEBUG_PORT%
goto :debug_port_done

:debug_port_done

:: set java options
set JAVA_OPTS=%JAVA_OPTS% ^
  -Dopenhab.home=%OPENHAB_HOME% ^
  -Dopenhab.conf=%OPENHAB_CONF% ^
  -Dopenhab.runtime=%OPENHAB_RUNTIME% ^
  -Dopenhab.userdata=%OPENHAB_USERDATA% ^
  -Dopenhab.logdir=%OPENHAB_LOGDIR% ^
  -Dfelix.cm.dir=%OPENHAB_USERDATA%\config ^
  -Djava.library.path=%OPENHAB_USERDATA%\tmp\lib ^
  -Djetty.host=%HTTP_ADDRESS% ^
  -Djetty.http.compliance=RFC2616 ^
  -Dnashorn.args=--no-deprecation-warning ^
  -Dorg.ops4j.pax.web.listening.addresses=%HTTP_ADDRESS% ^
  -Dorg.osgi.service.http.port=%HTTP_PORT% ^
  -Dorg.osgi.service.http.port.secure=%HTTPS_PORT% ^
  -Dlog4j2.formatMsgNoLookups=true

:: set jvm options
set EXTRA_JAVA_OPTS=-XX:+UseG1GC ^
  -Djava.awt.headless=true ^
  -Dfile.encoding=UTF-8 ^
  %EXTRA_JAVA_OPTS%
  
set JAVA_NON_DEBUG_OPTS=-XX:-UsePerfData

:: set JAVA_HOME if not set yet
rem Setup the Java Virtual Machine
if not "%JAVA%" == "" goto :Check_JAVA_END
    if not "%JAVA_HOME%" == "" goto :TryJDKEnd
:TryJRE
    start /w regedit /e __reg1.txt "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment"
    if not exist __reg1.txt goto :TryJDK
    type __reg1.txt | find "CurrentVersion" > __reg2.txt
    if errorlevel 1 goto :TryJDK
    for /f "tokens=2 delims==" %%x in (__reg2.txt) do set JavaTemp=%%~x
    if errorlevel 1 goto :TryJDK
    set JavaTemp=%JavaTemp%##
    set JavaTemp=%JavaTemp:                ##=##%
    set JavaTemp=%JavaTemp:        ##=##%
    set JavaTemp=%JavaTemp:    ##=##%
    set JavaTemp=%JavaTemp:  ##=##%
    set JavaTemp=%JavaTemp: ##=##%
    set JavaTemp=%JavaTemp:##=%
    del __reg1.txt
    del __reg2.txt
    start /w regedit /e __reg1.txt "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment\%JavaTemp%"
    if not exist __reg1.txt goto :TryJDK
    type __reg1.txt | find "JavaHome" > __reg2.txt
    if errorlevel 1 goto :TryJDK
    for /f "tokens=2 delims==" %%x in (__reg2.txt) do set JAVA_HOME=%%~x
    if errorlevel 1 goto :TryJDK
    del __reg1.txt
    del __reg2.txt
    goto TryJDKEnd
:TryJDK
    start /w regedit /e __reg1.txt "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"
    if not exist __reg1.txt (
        goto TryRegJRE
    )
    type __reg1.txt | find "CurrentVersion" > __reg2.txt
    if errorlevel 1 (
        goto TryRegJRE
    )
    for /f "tokens=2 delims==" %%x in (__reg2.txt) do set JavaTemp=%%~x
    if errorlevel 1 (
        goto TryRegJRE
    )
    set JavaTemp=%JavaTemp%##
    set JavaTemp=%JavaTemp:                ##=##%
    set JavaTemp=%JavaTemp:        ##=##%
    set JavaTemp=%JavaTemp:    ##=##%
    set JavaTemp=%JavaTemp:  ##=##%
    set JavaTemp=%JavaTemp: ##=##%
    set JavaTemp=%JavaTemp:##=%
    del __reg1.txt
    del __reg2.txt
    start /w regedit /e __reg1.txt "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit\%JavaTemp%"
    if not exist __reg1.txt (
        goto TryRegJRE
    )
    type __reg1.txt | find "JavaHome" > __reg2.txt
    if errorlevel 1 (
        goto TryRegJRE
    )
    for /f "tokens=2 delims==" %%x in (__reg2.txt) do set JAVA_HOME=%%~x
    if errorlevel 1 (
        goto TryRegJRE
    )
    del __reg1.txt
    del __reg2.txt
:TryRegJRE
    rem try getting the JAVA_HOME from registry
    FOR /F "usebackq tokens=3*" %%A IN (`REG QUERY "HKLM\Software\JavaSoft\Java Runtime Environment" /v CurrentVersion`) DO (
       set JAVA_VERSION=%%A
    )
    FOR /F "usebackq tokens=3*" %%A IN (`REG QUERY "HKLM\Software\JavaSoft\Java Runtime Environment\%JAVA_VERSION%" /v JavaHome`) DO (
       set JAVA_HOME=%%A %%B
    )
    if not exist "%JAVA_HOME%" (
       goto TryRegJDK
	)
	goto TryJDKEnd
:TryRegJDK
    rem try getting the JAVA_HOME from registry
    FOR /F "usebackq tokens=3*" %%A IN (`REG QUERY "HKLM\Software\JavaSoft\Java Development Kit" /v CurrentVersion`) DO (
       set JAVA_VERSION=%%A
    )
    FOR /F "usebackq tokens=3*" %%A IN (`REG QUERY "HKLM\Software\JavaSoft\Java Development Kit\%JAVA_VERSION%" /v JavaHome`) DO (
       set JAVA_HOME=%%A %%B
    )
    if not exist "%JAVA_HOME%" (
       echo Unable to retrieve JAVA_HOME from Registry
    )
	goto TryJDKEnd
:TryJDKEnd
    if not exist "%JAVA_HOME%" (
        echo JAVA_HOME is not valid: "%JAVA_HOME%"
        goto END
    )
    set JAVA=%JAVA_HOME%\bin\java
:Check_JAVA_END
