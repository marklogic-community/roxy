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

if [ "$1" == 'new' ]
then
  shift
  if [ $1 ]
  then
    app_name="$1"
    shift
    printf "\nCreating new Application: ${app_name}..."
    git clone https://github.com/marklogic/roxy ${app_name}
    cd ${app_name}
    rm -rf .git*
    ml init
    cd ..
    printf " done\n"
    if [ -e $app_name ]
    then
      while (( $# > 0 ))
      do
        token="$1"
        shift
        case "$token" in
          --git)
            printf "Creating a git repository:\n"
            cd ${app_name}
            echo `pwd`
            git init
            git add .
            git commit -m "Initial Commit"
            printf "...done\n"
            ;;
        *)
          usage
          exit 1
          ;;
        esac
      done
    fi
  else
    usage
  fi
else
  ruby deploy/lib/ml.rb $*
fi