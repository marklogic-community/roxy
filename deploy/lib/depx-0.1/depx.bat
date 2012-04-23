echo off


set DEPX_HOME=%~dp0

set COMMAND=%1

set PACKAGE=%2

set VERSION=%3
set APP_DIR=%cd:\=/%
echo depx 0.1, app dep management

echo Copyright (c) 2011, 2012 Jim Fuller

echo see https://github.com/xquery/depx

echo 
echo command: %COMMAND%

echo package: %PACKAGE%

echo version: %VERSION%

echo app dir: %APP_DIR%

echo 

echo depx processing ...


java -Xmx1024m -jar "%DEPX_HOME%deps\xmlcalabash\calabash.jar" -D %DEPX_HOME%libs\xproc\depx.xpl "command=%COMMAND%" "package=%PACKAGE%" "version=%VERSION%" "app_dir=file:///%APP_DIR%"


echo depx processing done

