(:
Copyright 2012-2015 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
xquery version "1.0-ml";

module namespace r = "http://marklogic.com/roxy/reflection";

declare option xdmp:mapping "false";

declare variable $r:PREVIOUS_LINE_FILE as xs:string :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    fn:concat($ex/error:stack/error:frame[3]/error:uri, " : Line ", $ex/error:stack/error:frame[3]/error:line)
  };

declare variable $r:__LINE__ as xs:int :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    $ex/error:stack/error:frame[2]/error:line
  };

declare variable $r:__FILE__ as xs:string :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    ($ex/error:stack/error:frame[2]/error:uri, "no file")[1]
  };

declare variable $r:__CALLER_FILE__ as xs:string :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    ($ex/error:stack/error:frame[3]/error:uri, "no file")[1]
  };