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
  printf "Usage: ml new app-name [--git]\n\n  use --git to automatically configure a git repo\n"
}

PARAMS=("${@}")

if [ "$1" == 'new' ]
then
  shift
  if [ $1 ]
  then
    app_name="$1"
    shift

    hash git 2>&- || { echo >&2 "Git is required to use the new command."; exit 1; }

    if [ -e $app_name ]
    then
      printf "\n${app_name} already exists. Aborting\n"
      exit 1
    fi

    BRANCH="master"
    INIT_GIT=0
    for (( i = 0; i < ${#PARAMS[@]}; i++ )); do
      if [[ ${PARAMS[${i}]} == --branch=* ]]
      then
        splits=(${PARAMS[${i}]//=/ })
        BRANCH=${splits[1]}
      elif [[ ${PARAMS[${i}]} == --git* ]]
      then
        INIT_GIT=1
      fi
    done

    printf "\nCreating new Application: ${app_name}..."
    git clone git://github.com/marklogic/roxy.git -b ${BRANCH} ${app_name}
    pushd ${app_name} > /dev/null
    rm -rf .git*
    ./ml init ${app_name}
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