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

IF not "%1"=="new" goto rubydeployer
SHIFT
IF "%1"=="" goto usage

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

IF EXIST %app_name% GOTO alreadyexists

echo.
echo Creating new Application: %app_name%...

cmd /c git clone git://github.com/marklogic/roxy.git %app_name%
pushd %app_name%
rmdir /Q /S .git
del /F /Q .gitignore
cmd /c ml init %app_name%
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
	echo Usage: ml new app-name [--git]
	echo.
	echo.
	echo   use --git to automatically configure a git repo
	echo.
	goto end

:end