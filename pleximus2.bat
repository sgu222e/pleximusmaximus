@ECHO OFF
REM Plex Windows Status Check and Restart
REM 2017 - Leigh Cameron
REM Use at your own risk, paths and names may need to be updated
REM GPL v3
REM Requires curl.exe and libcurl.dll to function -> https://curl.haxx.se/download.html (grab Win32 version and libcurl.dll)
REM I placed curl and libcurl.dll into the same path as the batch to keep it simple and portable.

REM SETLOCAL EnableExtensions	REM Leave this one alone

SET "PMSPATH=C:\Program Files (x86)\Plex\Plex Media Server"		REM Set you servers PMS Path Here!!!
SET "PLEXWEB=http://127.0.0.1:32400/web/index.html"				REM This is the web url for the local plex web app, it should work as is, but may require an edit.
SET "RMTWEB=http://127.0.0.1:32400"								REM Set to remote ip:port if wanted, or leave it with the default settings.

REM Do Not Edit Below this line!!! This means you Julius.
REM Global Variables
SET tmp_time=%time:~-11,2%%time:~-8,2%%time:~-5,2%
SET time_stamp=%tmp_time: =0%
SET LOGDIR=LOGS
SET WORKDIR=%cd%
SET EXENAME="Plex Media Server.exe"	REM This is the Plex Service name
SET "PEXE=Plex Media Server.exe"	REM This is for Tasklist to work
SET SNAKEEXE="PlexScriptHost.exe"   REM This is the Python sync service
SET "SEXE="PlexScriptHost.exe"   REM This is the Python sync service, for tasklist
SET ERR=0

REM This is where the work starts
cd /d %WORKDIR%

REM Switching to simplified logging until we can use Event Logs
:DIRCHECK
if exist %WORKDIR%\%LOGDIR%\nul goto PMSCHECK
mkdir %WORKDIR%\%LOGDIR%
goto PMSCHECK

REM This is the old logging, leaving it in for later
REM :DIRCHECK
REM if exist %WORKDIR%\%LOGDIR%%date:~-4,4%%date:~-7,2%%date:~-10,2%\nul goto :COPYLOG
REM mkdir %WORKDIR%\%LOGDIR%%date:~-4,4%%date:~-7,2%%date:~-10,2%
REM goto :COPYLOG

REM :COPYLOG
REM Copy over last fail log to todays directory and affix time and date stamp
REM cd /d %WORKDIR%
REM move fail.log %WORKDIR%\%LOGDIR%%date:~-4,4%%date:~-7,2%%date:~-10,2%\fail%date:~-4,4%%date:~-7,2%%date:~-10,2%-%time_stamp%.log
REM goto :TRIMOLD

REM :TRIMOLD
REM Check for and remove any log directory older than 7 days
REM forfiles.exe /p %WORKDIR% /s /d -7 /c "cmd /c rmdir /s /q @file"
REM goto PMSCHECK

:PMSCHECK
FOR /F "tokens=1 delims=,  " %%x IN ('tasklist /NH /FO CSV /FI "IMAGENAME eq %PEXE%"') DO IF %%x == "%PEXE%" goto started
echo PMS is not running - %time_stamp%>>fail.log
echo PMS is not running, must restart Plex Service!
goto DASBOOT

echo unknown status
goto endbad
:trouble
echo Oh noooo.. trouble, use manual intervention, or call someone you trust
goto endbad
:started
echo %PEXE% is started, keep calm and carry on
goto web

:web
REM Perform a sanity check on the web app, just incase the service is running but plex is still hung (not that way you dirty minded twit)
cd /d %WORKDIR%
curl -I %PLEXWEB% | FIND "200 OK"
if %ERRORLEVEL% == 1 goto webstop
if %ERRORLEVEL% == 0 goto webok
echo unknown status
goto endbad
:webok
echo All is well on the webfront, carry on
goto RMTCHECK
:webstop
echo Plex Web App not responding - %time_stamp%>>fail.log
echo Web app not responding, must restart Plex Service!
goto DASBOOT

:RMTCHECK
REM Perform a sanity check on remote IP and port, requested feature for GO
cd /d %WORKDIR%
curl -I %RMTWEB% | FIND "200 OK"
if %ERRORLEVEL% == 1 goto rmtstop
if %ERRORLEVEL% == 0 goto rmtok
echo unknown status
goto endbad
:rmtok
echo All is well on Remote server, carry on
goto SNAKECHECK
:rmtstop
echo Remote server not responding - %time_stamp%>>fail.log
echo Remote server not responding, must restart Plex Service!
goto DASBOOT


:SNAKECHECK
REM Added to try and eliminate Python hung on sync tasks. I hate snakes, Jock - Indiana Jones
cd /d %WORKDIR%
curl -I %PLEXWEB% | FIND "503"
if %ERRORLEVEL% == 1 goto SAULGOOD
if %ERRORLEVEL% == 0 goto STPATRICK
echo unknown status
goto endbad
:SAULGOOD
echo Seems like Python hasnt locked up, carry on
goto CHECKERR
:STPATRICK
REM Kill Python, Kill PMS, Restart PMS
echo Python is probably locked up - %time_stamp%>>fail.log
echo Web app not responding, Pythons fault, must restart Plex Service!
goto DASBOOT

:DASBOOT
echo Terminating Python executable
taskkill /F /IM "%SEXE%" /T
ping 127.0.0.1 -n 10 > nul		REM This is effectively a sleep for 10 seconds, adjust as needed... or follow the rule above.
echo Terminating Python executable again, just incase
taskkill /F /IM "%SEXE%" /T
ping 127.0.0.1 -n 10 > nul		REM This is effectively a sleep for 10 seconds, adjust as needed... or follow the rule above.
echo Terminating Plex Media Server
taskkill /F /IM "%PEXE%" /T
ping 127.0.0.1 -n 10 > nul		REM This is effectively a sleep for 10 seconds, adjust as needed... or follow the rule above.
echo Starting Plex Media Server
cd /d %PMSPATH%
start "" %EXENAME%
cd /d %WORKDIR%
SET /a "ERR=%ERR%+1"
goto CHECKERR

:endbad
Echo Something really bad happened
SET ERR=9
exit /b %ERR%

:CHECKERR
REM Check the error count, if 0 than all is well, else change the code in Task Scheduler
IF NOT %ERR% == 0 goto :ENDFAIL
goto :end

:ENDFAIL
REM Exit out and give an error indicating that something failed
exit /b %ERR%

:end
exit /b 0
