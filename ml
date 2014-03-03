#!/bin/bash
###############################################################################
# Copyright 2012 MarkLogic Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

hash ruby 2>&- || { echo >&2 "Ruby is required to run the ml scripts."; exit 1; }

usage()
{
  printf "Usage: ml new app-name --server-version=[version-number] [--branch=branch] [--app-type=mvc|hybrid|rest] [--git]\n
  use --git to automatically configure a git repo
  use --branch to specify the GitHub branch of the Roxy project your project
    will be based on (master, dev)
  use --app-type to specify the project type:
    mvc: a Roxy MVC project
    rest: a MarkLogic REST API project
    hybrid: a hybrid of both types
  use --force to force installation into an existing directory\n"
}

PARAMS=("${@}")

if [ "$1" == 'new' ]
then
  shift
  if [[ "$1" == '-h' ]]
  then
    usage
  elif [ $1 ]
  then
    app_name="$1"
    shift

    hash git 2>&- || { echo >&2 "Git is required to use the new command."; exit 1; }

    BRANCH="master"
    INIT_GIT=0
    FORCE_INSTALL=0
    APPTYPE="mvc"
    for (( i = 0; i < ${#PARAMS[@]}; i++ )); do
      if [[ ${PARAMS[${i}]} == --branch=* ]]
      then
        splits=(${PARAMS[${i}]//=/ })
        BRANCH=${splits[1]}
      elif [[ ${PARAMS[${i}]} == --git* ]]
      then
        INIT_GIT=1
      elif [[ ${PARAMS[${i}]} == --force* ]]
      then
        FORCE_INSTALL=1
      elif [[ ${PARAMS[${i}]} == --app-type* ]]
      then
        splits=(${PARAMS[${i}]//=/ })
        APPTYPE=${splits[1]}
      fi
    done

    if [ -e $app_name ] && [ ${FORCE_INSTALL} == 0 ]
    then
      printf "\n${app_name} already exists. Aborting\n"
      exit 1
    fi

    if [ "$APPTYPE" != "mvc" ] && [ "$APPTYPE" != "rest" ] && [ "$APPTYPE" != "hybrid" ]
    then
      printf "\nValid values for app-type are mvc, rest and hybrid. Aborting\n"
      exit 1
    fi

    printf "\nCreating new Application: ${app_name}..."
    if [ -e $app_name ]
    then
      git clone git://github.com/marklogic/roxy.git -b ${BRANCH} ${app_name}.tmp_1
      mv ${app_name}.tmp_1/* ${app_name}/
      rm -rf ${app_name}.tmp_1
    else
      git clone git://github.com/marklogic/roxy.git -b ${BRANCH} ${app_name}
    fi

    pushd ${app_name} > /dev/null
    rm -rf .git*
    if [ "$APPTYPE" = "rest" ]
    then
      # For a REST application, we won't be using the MVC code. Remove it.
      # mvc and hybrid apps will use it.
      rm -rf src/*
      printf "\nNo initial source code is provided for REST apps. You can copy code from Application Builder under the source directory.\n"
    fi

    ./ml init ${app_name} ${@}
    popd > /dev/null
    printf " done\n"
    if [ -e $app_name ]
    then
      if [ ${INIT_GIT} == 1 ]
      then
        printf "Creating a git repository:\n"
        cd ${app_name}
        git init
        git add .
        git commit -q -m "Initial Commit"
        printf "...done\n"
      fi
    fi
  else
    usage
  fi
elif [ "$1" == 'self-test' ]
then
  if [ -e deploy/test/test_main.rb ]
  then
    ruby -I deploy -I deploy/lib -I deploy/test deploy/test/test_main.rb
  else
    printf "\nERROR: You must run this command inside a valid Roxy Project\n\n"
  fi
else
  if [ -e deploy/lib/ml.rb ]
  then
    ruby -I deploy -I deploy/lib deploy/lib/ml.rb $*
  else
    printf "\nERROR: You must run this command inside a valid Roxy Project\n\n"
  fi
fi