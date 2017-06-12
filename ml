#!/bin/bash
###############################################################################
# Copyright 2012-2015 MarkLogic Corporation
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
  printf "Usage: ml new app-name --server-version=[version-number] [--branch=branch] [--app-type=bare|mvc|hybrid|rest] [--git]\n
  use --git to automatically configure a git repo
  use --branch to specify the GitHub branch of the Roxy project your project
    will be based on (master, dev)
  use --app-type to specify the project type:
    bare: a bare Roxy project
    mvc: a Roxy MVC project
    rest: a MarkLogic REST API project
    hybrid: a hybrid of MVC and REST types
  use --force to force installation into an existing directory\n"
}

PARAMS=("$@")

if [ "$1" == 'new' ]
then
  shift
  if [ "$1" == '-h' ] || [ "$1" == '--help' ]
  then
    usage
  elif [ $1 ]
  then
    # check if we are already in a valid Roxy project
    if [ -e deploy/lib/ml.rb ]
    then
      read -r -n 1 -p "Running ml new from within a Roxy project is not recommended. Continue? [y/N] " response
      printf "\n"
      if [[ $response != "Y" ]] && [[ $response != "y" ]]
      then
        exit 1
      fi
    fi

    app_name="$1"
    shift

    hash git 2>&- || { echo >&2 "Git is required to use the new command."; exit 1; }

    BRANCH="master"
    INIT_GIT=0
    FORCE_INSTALL=0
    APPTYPE="mvc"
    FORK="marklogic"
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
      elif [[ ${PARAMS[${i}]} == --app-type=* ]]
      then
        splits=(${PARAMS[${i}]//=/ })
        APPTYPE=${splits[1]}
      elif [[ ${PARAMS[${i}]} == --fork=* ]]
      then
        splits=(${PARAMS[${i}]//=/ })
        FORK=${splits[1]}
      fi
    done

    if [ -e $app_name ] && [ ${FORCE_INSTALL} == 0 ]
    then
      printf "\n${app_name} already exists. Aborting\n"
      exit 1
    fi

    if [ "$APPTYPE" != "bare" ] && [ "$APPTYPE" != "mvc" ] && [ "$APPTYPE" != "rest" ] && [ "$APPTYPE" != "hybrid" ]
    then
      printf "\nValid values for app-type are bare, mvc, rest and hybrid. Aborting\n"
      exit 1
    fi

    printf "\nCreating new Application: ${app_name}...\n"
    if [ -e $app_name ]
    then
      git clone git://github.com/${FORK}/roxy.git -b ${BRANCH} ${app_name}.tmp_1 || exit 1
      mv ${app_name}.tmp_1/* ${app_name}/ || exit 1
      rm -rf ${app_name}.tmp_1 || exit 1
    else
      git clone git://github.com/${FORK}/roxy.git -b ${BRANCH} ${app_name} || exit 1
    fi

    pushd ${app_name} > /dev/null  || exit 1
    rm -rf .git* || exit 1
    if [ "$APPTYPE" != "mvc" ] && [ "$APPTYPE" != "hybrid" ]
    then
      # For non-MVC applications, we won't be using the MVC code. Remove it.
      rm -rf src/* || exit 1
      printf "\nNo initial source code is provided for non-MVC apps. You can capture code from a REST application, or add your own code.\n"
    fi

    ./ml init ${app_name} "$@" || exit 1
    popd > /dev/null || exit 1
    printf " done\n"
    if [ -e $app_name ]
    then
      if [ ${INIT_GIT} == 1 ]
      then
        printf "Creating a git repository:\n"
        cd ${app_name}
        git init || exit 1
        git add . || exit 1
        git commit -q -m "Initial Commit" || exit 1
        printf "...done\n"
      fi
    fi
  else
    printf "\nNOTE: Please provide an app name..\n\n"
    usage
  fi
elif [ "$1" == 'self-test' ]
then
  if [ -e deploy/test/test_main.rb ]
  then
    # Look for --server-version param, and export that as env variable. Unit testing doesn't allow cmd params..
    for (( i = 0; i < ${#PARAMS[@]}; i++ )); do
      if [[ ${PARAMS[${i}]} == --server-version=* ]]
      then
        splits=(${PARAMS[1]//=/ })
        # This exports the version only to sub-processes, e.g. the ruby call below..
        export ROXY_TEST_SERVER_VERSION=${splits[1]}
      fi
    done
    ruby -I deploy -I deploy/lib -I deploy/test deploy/test/test_main.rb || exit 1
  else
    printf "\nERROR: You must run this command inside a valid Roxy Project. Use 'ml new' to create a project.\n\n"
    usage
  fi
else
  if [ -e deploy/lib/ml.rb ]
  then
    ruby -I deploy -I deploy/lib deploy/lib/ml.rb "$@" || exit $?
  else
    printf "\nERROR: You must run this command inside a valid Roxy Project. Use 'ml new' to create a project.\n\n"
    usage
  fi
fi
