@echo off

set RUBYFOUND=
for %%e in (%PATHEXT%) do (
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
IF "%1"=="" goto usage
IF "%1"=="-h" goto usage

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
  	shift
  )
  shift
  goto :loop
)

if "%FORCE_INSTALL%"=="1" GOTO skip_already_exists

if EXIST %app_name% GOTO alreadyexists

:skip_already_exists

if not "%APPTYPE%"=="mvc" if not "%APPTYPE%"=="rest" if not "%APPTYPE%"=="hybrid" (
  echo Valid values for app-type are mvc, rest and hybrid. Aborting.
  exit /b
)

echo.
echo Creating new Application: %app_name%...

if EXIST %app_name% (
	cmd /c git clone git://github.com/marklogic/roxy.git -b %BRANCH% %app_name%.tmp_1
	xcopy %app_name%.tmp_1\* %app_name%\ /E
	rmdir /s /q %app_name%.tmp_1
)
if NOT EXIST %app_name% (
	cmd /c git clone git://github.com/marklogic/roxy.git -b %BRANCH% %app_name%
)

pushd %app_name%
rmdir /Q /S .git
del /F /Q .gitignore

if "%APPTYPE%"=="rest" (
  REM For a REST application, we won't be using the MVC code. Remove it.
  REM mvc and hybrid apps will use it.
  rmdir /S /Q src
  mkdir src
  echo.
  echo No initial source code is provided for REST apps. You can copy code from Application Builder under the source directory.
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
	ruby -Ideploy -Ideploy\lib -Ideploy\test deploy\test\test_main.rb
	goto end

:rubydeployer
	if NOT EXIST deploy\lib\ml.rb GOTO missingdeploy
	ruby -Ideploy -Ideploy\lib deploy\lib\ml.rb %*
	goto end

:missingdeploy
	echo.
	echo You must run this command inside a valid Roxy Project
	echo.
	goto end

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
	echo %app_name% already exists. Aborting
	echo.
	goto end

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
