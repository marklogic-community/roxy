(:
Copyright 2012 MarkLogic Corporation

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

import module namespace cvt = "http://marklogic.com/cpf/convert"
      at "/MarkLogic/conversion/convert.xqy";

import module namespace m="http://marklogic.com/roxy/test-runner" at "/test/lib/test-runner.xqy";

import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare namespace dir = "http://marklogic.com/xdmp/directory";
declare namespace error = "http://marklogic.com/xdmp/error";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace t="http://marklogic.com/roxy/test";

declare variable $FS-PATH  as xs:string :=
    if(xdmp:platform() eq "winnt") then "\" else "/";

declare option xdmp:mapping "false";

declare function local:format-junit($suite as element())
{
  element testsuite
  {
    attribute errors { fn:data($suite/@errors) },
    attribute failures { fn:data($suite/@failures) },
    attribute hostname { fn:tokenize(xdmp:get-request-header("Host"), ":")[1] },
    attribute name { fn:data($suite/@name) },
    attribute tests { fn:data($suite/@assertions) },
    attribute time { fn:data($suite/@time) },
    attribute timestamp { "" },
    for $test in $suite/t:*
    let $localname := fn:local-name($test)
    return
      if ($localname = "assertion")
      then 
        element testcase {
          attribute classname { fn:data($test/@name) },
          attribute name { fn:data($test/@name) },
          attribute time { fn:data($test/@time) },
          if (fn:string($test/@type) eq "failure") then
            element failure
            {
              attribute type { fn:data($test/error:error/error:name) },
              attribute message { fn:data($test/error:error/error:message) },
              xdmp:quote($test/error:error)
            }
          else ()
        }
      else 
        element testcase {
          attribute classname { fn:data($test/@name) },
          attribute name { fn:data($test/@name) },
          attribute time { fn:data($test/@time) },
          element error {
            attribute type { fn:data($test/error:error/error:name) },
            attribute message { fn:data($test/error:error/error:message) },
            xdmp:quote($test/error:error)
          }
        }
  }
};


declare function local:run() {
  let $test := fn:tokenize(xdmp:get-request-field("test", ""), ",")[. ne ""]
  let $assertions := fn:tokenize(xdmp:get-request-field("assertions", ""), ",")[. ne ""]
  let $run-teardown as xs:boolean := xdmp:get-request-field("runteardown", "") eq "true"
  let $format as xs:string := xdmp:get-request-field("format", "xml")
  
  let $result :=
    if ($test) then
      m:run-test($test, $assertions, $run-teardown)
    else
      ()
  return
    if ($format eq "junit") then
      local:format-junit($result)
    else
      $result
};

declare function local:list()
{
  m:list()
};

declare function local:all()
{
  let $all-tests := m:run-tests(m:list()/t:test/@path/fn:string(.))
  let $format as xs:string := xdmp:get-request-field('format', 'xml')
  return if($format eq "junit")
    then
      element testsuites {
        for $test in $all-tests/*:test
        return local:format-junit($test)
      }
    else
      $all-tests
};


(:~
 : Provides the UI for the test framework to allow selection and running of tests
 :)
declare function local:main() {
  xdmp:set-response-content-type("text/html"),
  let $app-server := xdmp:server-name(xdmp:server())
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title>{$app-server} Unit Tests</title>
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <link rel="stylesheet" type="text/css" href="css/tests.css" />
        <link rel="stylesheet" type="text/css" href="css/jquery.gritter.css" />
        <script type="text/javascript" src="js/jquery-1.6.2.min.js"></script>
        <script type="text/javascript" src="js/jquery.gritter.min.js"></script>
        <script type="text/javascript" src="js/tests.js"></script>
      </head>
      <body>
        <div id="warning">
          <img src="img/warning.png" width="30" height="30"/>BEWARE OF DOG: Unit tests will wipe out your data!!<img src="img/warning.png" width="30" height="30"/>
          <div id="db-info">Current Database: <span>{xdmp:database-name(xdmp:database())}</span></div>
        </div>
        <div>
        <div id="overview" style="float:left;">
          <h2>{$app-server} Unit Tests:&nbsp;<span id="test-results"/></h2>

        </div>
        <div style="float:right;">
            <input class="runtests button" type="submit" value="Run Tests" title="(ctrl-enter) works too!"/>
            <input class="canceltests button" type="submit" value="Cancel Tests" title="(Cancel key) works too!"/>
        </div>
        </div>
        <table cellspacing="0" cellpadding="0" id="tests">
          <thead>
            <tr>
              <th><input id="checkall" type="checkbox" checked="checked"/>Run</th>
              <th>Test</th>
              <th>Total Assertions</th>
              <th>Successes</th>
              <th>Failures</th>
              <th>Errors</th>
            </tr>
          </thead>

          <tbody>
          {
            let $tests := m:list()
            for $test at $index in $tests/t:test
            let $name := cvt:basename($test/@path)
            let $class := if ($index mod 2 = 1) then "odd" else "even"
            return
            (
              <tr class="{$class}">
                <td class="left"><input class="cb" type="checkbox" checked="checked" value="{fn:data($test/@path)}"/></td>
                <td>
                  <div class="test-name">
                    <img class="tests-toggle-plus" src="img/arrow-right.gif"/>
                    <img class="tests-toggle-minus" src="img/arrow-down.gif"/>
                    {$name} <span class="spinner"><img src="img/spinner.gif"/><b>Running...</b></span>
                  </div>

                </td>
                <td class="assertions">-</td>
                <td class="successes">-</td>
                <td class="right failures">-</td>
                <td class="right errors">-</td>
              </tr>,
              <tr class="{$class}">
                <td colspan="6">
                <div class="tests">
                  <div class="wrapper"><input class="check-all-tests" type="checkbox" checked="checked"/>Run All Assertions</div>
                  <ul class="tests">
                    <li class="setup"><span class="outcome"></span></li>
                    {
                      for $assertion as xs:string in $test/t:assertions/t:assertion
                      return
                        <li class="tests"><input class="test-cb" type="checkbox" checked="checked" value="{$assertion}"/>{$assertion}<span class="outcome"></span></li>
                    }
                    <li class="teardown"><span class="outcome"></span></li>
                  </ul>
                </div>
                </td>
              </tr>
            )
          }
          </tbody>
        </table>
        <table cellspacing="0" cellpadding="0" >
          <thead>
            <tr>
              <th>Options</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><label for="runteardown">Run Teardown after each test</label><input id="runteardown" type="checkbox" checked="checked"/></td>
            </tr>
          </tbody>
        </table>
        <input class="runtests button" type="submit" value="Run Tests" title="(ctrl-enter) works too!"/>
        <input class="canceltests button" type="submit" value="Cancel Tests" title="(Cancel key) works too!"/>
        <p class="render-time">Page Rendered in: {xdmp:elapsed-time()}</p>
      </body>
    </html>
};

let $func := xdmp:function(xs:QName(fn:concat("local:", xdmp:get-request-field("func", "main"))))
return
  xdmp:apply($func)