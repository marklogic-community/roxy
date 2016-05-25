@echo off

set RUBYFOUND=
for %%e in (%PATHEXT%) do (
  for %%X in (jruby%%e) do (
    if not defined RUBYFOUND (
      set RUBYFOUND=%%~$PATH:X
    )
  )
  for %%X in (ruby%%e) do (
    if not defined RUBYFOUND (
      set RUBYFOUND=%%~$PATH:X
    )
  )
)
if not defined RUBYFOUND goto needruby

if "%1"=="self-test" goto selftest

IF not "%1"=="new" goto rubydeployer
SHIFT
IF "%1"=="" goto providename
IF "%1"=="-h" goto usage
IF "%1"=="--help" goto usage

REM check if we are already in a valid Roxy project
if NOT EXIST deploy\lib\ml.rb GOTO skip_roxy_exists
set /p response= "Running ml new from within a Roxy project is not recommended. Continue? [y/N] "
if /i "%response:~,1%" NEQ "Y" exit /b

:skip_roxy_exists

set app_name=%1
SHIFT

set GITFOUND=
for %%e in (%PATHEXT%) do (
  for %%X in (git%%e) do (
    if not defined GITFOUND (
      set GITFOUND=%%~$PATH:X
    )
  )
)
if not defined GITFOUND goto needgit

set BRANCH=master
set INIT_GIT=0
set APPTYPE=mvc
set FORCE_INSTALL=0
set FORK=marklogic

:loop
if not "%1"=="" (
  if "%1"=="--branch" (
    set BRANCH=%2
    shift
  )
  if "%1"=="--app-type" (
    set APPTYPE=%2
    shift
  )
  if "%1"=="--force" (
    set FORCE_INSTALL=1
  )
  if "%1"=="--fork" (
    set FORK=%2
    shift
  )
  shift
  goto :loop
)

if "%FORCE_INSTALL%"=="1" GOTO skip_already_exists

if EXIST %app_name% GOTO alreadyexists

:skip_already_exists

if not "%APPTYPE%"=="bare" if not "%APPTYPE%"=="mvc" if not "%APPTYPE%"=="rest" if not "%APPTYPE%"=="hybrid" (
  echo Valid values for app-type are bare, mvc, rest and hybrid. Aborting.
  exit /b
)

echo.
echo Creating new Application: %app_name%...

REM TODO: check errorlevel and bail out if any of the below commands fail..

if EXIST %app_name% (
  cmd /c git clone git://github.com/%FORK%/roxy.git -b %BRANCH% %app_name%.tmp_1
  xcopy %app_name%.tmp_1\* %app_name%\ /E
  rmdir /s /q %app_name%.tmp_1
)
if NOT EXIST %app_name% (
  cmd /c git clone git://github.com/%FORK%/roxy.git -b %BRANCH% %app_name%
)

pushd %app_name%
rmdir /Q /S .git
del /F /Q .gitignore

if not "%APPTYPE%"=="mvc" if not "%APPTYPE%"=="hybrid" (
  REM For non-MVC applications, we won't be using the MVC code. Remove it.
  rmdir /S /Q src
  mkdir src
  echo.
  echo No initial source code is provided for non-MVC apps. You can capture code from a REST application, or add your own code.
)

for /f "tokens=1-2*" %%a in ("%*") do (
  set arg-command=%%a
  set arg-appname=%%b
  set arg-options=%%c
)

cmd /c ml init %app_name% %arg-options%

popd
echo  done
echo.

IF NOT EXIST %app_name% GOTO end
if not "%1"=="--git" goto end

pushd %app_name%

echo Creating a git repository
echo.

cmd /c git init
cmd /c git add .
cmd /c git commit -q -m "Initial Commit"

echo ...done
echo.

popd

goto end

:selftest
  if NOT EXIST deploy\test\test_main.rb GOTO missingdeploy

  REM Save original env variable value
  set ROXY_TEST_SERVER_VERSION_ORG=%ROXY_TEST_SERVER_VERSION%

:loop2
  if not "%1"=="" (
    REM Look for --server-version param, and export that as env variable. Unit testing doesn't allow cmd params..
    if "%1"=="--server-version" (
      set ROXY_TEST_SERVER_VERSION=%2
      shift
    )
    shift
    goto :loop2
  )

  "%RUBYFOUND%" -Ideploy -Ideploy\lib -Ideploy\test deploy\test\test_main.rb

  REM Restore original env variable value
  set ROXY_TEST_SERVER_VERSION=%ROXY_TEST_SERVER_VERSION_ORG%
  set ROXY_TEST_SERVER_VERSION_ORG=
  goto end

:rubydeployer
  if NOT EXIST deploy\lib\ml.rb GOTO missingdeploy
  "%RUBYFOUND%" -Ideploy -Ideploy\lib deploy\lib\ml.rb %*
  goto end

:missingdeploy
  echo.
  echo You must run this command inside a valid Roxy Project. Use 'ml new' to create a project.
  echo.
  goto usage

:needruby
  echo.
  echo Ruby is required to run the ml scripts.
  echo.
  goto end

:needgit
  echo.
  echo Git is required to use the new command.
  echo.
  goto end

:alreadyexists
  echo.
  echo %app_name% already exists. Aborting.
  echo.
  goto end

:providename
  echo.
  echo "NOTE: Please provide an app name.."
  echo.

:usage
  echo Usage: ml new app-name --server-version=[version] [--branch=branch] [--git] [--force]
  echo.
  echo.
  echo   use --server-version to specify the major version of MarkLogic you will
  echo     target in your project (4, 5, 6, 7)
  echo   use --branch to specify the GitHub branch of the Roxy project your project
  echo     will be based on (master, dev)
  echo   use --git to automatically configure a git repo
  echo   use --force to overwrite an existing directory
  echo.
  goto end

:end
