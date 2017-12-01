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

(:import module namespace test="http://marklogic.com/roxy/test" at "/test/unit-test.xqy";:)

import module namespace cvt = "http://marklogic.com/cpf/convert"
      at "/MarkLogic/conversion/convert.xqy";

import module namespace helper="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare namespace dir = "http://marklogic.com/xdmp/directory";
declare namespace error = "http://marklogic.com/xdmp/error";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace t="http://marklogic.com/roxy/test";

declare variable $FS-PATH  as xs:string :=
    if(xdmp:platform() eq "winnt") then "\" else "/";

declare option xdmp:mapping "false";

(:~
 : Returns a list of the available tests. This list is magically computed based on the modules
 :)
declare function t:list() {
  let $suite-ignore-list := (".svn", "CVS", ".DS_Store", "Thumbs.db", "thumbs.db", "test-data")
  let $test-ignore-list := (
    "setup.xqy", "teardown.xqy", "setup.sjs", "teardown.sjs",
    "suite-setup.xqy", "suite-teardown.xqy", "suiteSetup.sjs", "suiteTeardown.sjs"
  )
  return
    element t:tests {
      let $db-id as xs:unsignedLong := xdmp:modules-database()
      let $root as xs:string := xdmp:modules-root()
      let $suites as xs:string* :=
        if ($db-id = 0) then
          xdmp:filesystem-directory(fn:concat($root, $FS-PATH, "test/suites"))/dir:entry[dir:type = "directory" and fn:not(dir:filename = $suite-ignore-list)]/dir:filename
        else
          let $uris := helper:list-from-database($db-id, $root, ())
          return
            fn:distinct-values(
              for $uri in $uris
              let $path := fn:replace(cvt:basepath($uri), fn:concat($root, "test/suites/?"), "")
              where $path ne "" and fn:not(fn:contains($path, "/")) and fn:not($path = $suite-ignore-list)
              return
                $path)
      for $suite as xs:string in $suites
      let $tests as xs:string* :=
        if ($db-id = 0) then
          xdmp:filesystem-directory(fn:concat($root, $FS-PATH, "test/suites/", $suite))/dir:entry[dir:type = "file" and fn:not(dir:filename = $test-ignore-list)]/dir:filename[fn:ends-with(., ".xqy") or fn:ends-with(., ".sjs")]
        else
          let $uris := helper:list-from-database(
            $db-id, $root, fn:concat($suite, '/'))
          return
            fn:distinct-values(
              for $uri in $uris
              let $path := fn:replace($uri, fn:concat($root, "test/suites/", $suite, "/"), "")
              where $path ne "" and fn:not(fn:contains($path, "/")) and fn:not($path = $test-ignore-list) and (fn:ends-with($path, ".xqy") or fn:ends-with($path, ".sjs"))
              return
                $path)
      where $tests
      return
        element t:suite {
          attribute path { $suite },
          element t:tests {
            for $test in $tests
            return
              element t:test {
                attribute path { $test }
              }
          }
        }
    }
};

declare private function t:run-setup-teardown(
  $is-setup as xs:boolean,
  $suite as xs:string
)
{
  let $start-time := xdmp:elapsed-time()
  let $stage := if ($is-setup) then "setup" else "teardown"
  let $xquery-script := "suite-" || $stage || ".xqy"
  let $sjs-script := "suite" || xdmp:initcap($stage) || ".sjs"
  return
    try {
      helper:log(" - invoking suite " || $stage),
      xdmp:invoke("suites/" || $suite || "/" || $xquery-script)
    }
    catch($ex) {
      if (($ex/error:code = "XDMP-MODNOTFOUND" and
           fn:matches($ex/error:stack/error:frame[1]/error:uri/fn:string(), "/" || $xquery-script || "$")) or
          ($ex/error:code = "SVC-FILOPN" and
           fn:matches($ex/error:expr, $xquery-script))) then
        try {
          xdmp:invoke("suites/" || $suite || "/" || $sjs-script)
        }
        catch ($ex) {
          if (($ex/error:code = "XDMP-MODNOTFOUND" and
               fn:matches($ex/error:stack/error:frame[1]/error:uri/fn:string(), "/" || $sjs-script || "$")) or
              ($ex/error:code = "SVC-FILOPN" and
               fn:matches($ex/error:expr, $sjs-script))) then
            ()
          else
            element t:test {
              attribute name { $sjs-script },
              attribute time { functx:total-seconds-from-duration(xdmp:elapsed-time() - $start-time) },
              element t:result {
                attribute type {"fail"},
                $ex
              }
            }
        }
      else
        element t:test {
          attribute name { $xquery-script },
          attribute time { functx:total-seconds-from-duration(xdmp:elapsed-time() - $start-time) },
          element t:result {
            attribute type {"fail"},
            $ex
          }
        }
    }
};

declare function t:run-suite($suite as xs:string, $tests as xs:string*, $run-suite-teardown as xs:boolean, $run-teardown as xs:boolean) {
  let $start-time := xdmp:elapsed-time()
  let $results :=
    element t:run {
      helper:log(" "),
      helper:log(text {"SUITE:", $suite}),
      t:run-setup-teardown(fn:true(), $suite),

      helper:log(" - invoking tests"),

      let $tests as xs:string* :=
        if ($tests) then $tests
        else
          t:list()/t:suite[@path = $suite]/t:tests/t:test/@path
      for $test in $tests
      return
        t:run($suite, $test, fn:concat("suites/", $suite, "/", $test), $run-teardown),

      if ($run-suite-teardown eq fn:true()) then
        t:run-setup-teardown(fn:false(), $suite)
      else helper:log(" - not running suite teardown"),
      helper:log(" ")
    }
  let $end-time := xdmp:elapsed-time()
  return
    element t:suite {
      attribute name { $suite },
      attribute total { fn:count($results/t:test/t:result) },
      attribute passed { fn:count($results/t:test/t:result[@type = 'success']) },
      attribute failed { fn:count($results/t:test/t:result[@type = 'fail']) },
      attribute time { functx:total-seconds-from-duration($end-time - $start-time) },
      $results/*/self::t:test
    }
};

declare private function t:run-setup-or-teardown($setup as xs:boolean, $suite as xs:string)
{
  let $stage := if ($setup) then "setup" else "teardown"
  let $xquery-script := $stage || ".xqy"
  let $sjs-script := $stage || ".sjs"
  return
    try {
      (: We don't want the return value, so return () :)
      let $_ := helper:log("    ...invoking " || $stage)
      let $_ := xdmp:invoke("suites/" || $suite || "/" || $xquery-script)
      return ()
    }
    catch($ex) {
      if (($ex/error:code = "XDMP-MODNOTFOUND" and
           fn:matches($ex/error:stack/error:frame[1]/error:uri/fn:string(), "/" || $xquery-script || "$")) or
          ($ex/error:code = "SVC-FILOPN" and
           fn:matches($ex/error:expr, $xquery-script))) then
        try {
          xdmp:invoke("suites/" || $suite || "/" || $sjs-script)
        }
        catch($ex) {
          if (($ex/error:code = "XDMP-MODNOTFOUND" and
               fn:matches($ex/error:stack/error:frame[1]/error:uri/fn:string(), "/" || $sjs-script || "$")) or
              ($ex/error:code = "SVC-FILOPN" and
               fn:matches($ex/error:expr, $sjs-script))) then
            ()
          else
            element t:result {
              attribute type {"fail"},
              $ex
            }
        }
      else
        element t:result {
          attribute type {"fail"},
          $ex
        }
    }
};

declare function t:run($suite as xs:string, $name as xs:string, $module, $run-teardown as xs:boolean) {
  helper:log(text { "    TEST:", $name }),
  let $start-time := xdmp:elapsed-time()
  let $setup := t:run-setup-or-teardown(fn:true(), $suite)
  let $result :=
    try {
      if (fn:not($setup/@type = "fail")) then
        (: Avoid returning result of helper:log :)
        let $_ := helper:log("    ...running")
        return xdmp:invoke($module)
      else
        ()
    }
    catch($ex) {
      helper:fail($ex)
    }
  (: If we had a .sjs test module, we may get arrays back. Convert the array
   : of results to a sequence of results.
   :)
  let $result :=
    if ($result instance of json:array) then
      json:array-values($result)
    else
      $result
  let $teardown :=
    if ($run-teardown eq fn:true() and fn:not($setup/@type = "fail")) then
      t:run-setup-or-teardown(fn:false(), $suite)
    else
      helper:log("    ...not running teardown")
  let $end-time := xdmp:elapsed-time()
  return
    element t:test {
      attribute name { $name },
      attribute time { functx:total-seconds-from-duration($end-time - $start-time) },
      $setup,
      $result,
      $teardown
    }
};

declare function local:format-junit($suite as element())
{
  element testsuite
  {
    attribute errors { "0" },
    attribute failures { fn:data($suite/@failed) },
    attribute hostname { fn:tokenize(xdmp:get-request-header("Host"), ":")[1] },
    attribute name { fn:data($suite/@name) },
    attribute tests { fn:data($suite/@total) },
    attribute time { fn:data($suite/@time) },
    attribute timestamp { "" },
    for $test in $suite/t:test
    return
      element testcase
      {
        attribute classname { fn:data($test/@name) },
        attribute name { fn:data($test/@name) },
        attribute time { fn:data($test/@time) },
        for $result in ($test/t:result)[1]
        return
          if ($result/@type = "fail") then
            element failure
            {
              attribute type { fn:data($result/error:error/error:name) },
              attribute message { fn:data($result/error:error/error:message) },
              xdmp:quote($result/error:error)
            }
          else ()
      }
  }
};


declare function local:run() {
  let $suite := xdmp:get-request-field("suite")
  let $tests := fn:tokenize(xdmp:get-request-field("tests", ""), ",")[. ne ""]
  let $run-suite-teardown as xs:boolean := xdmp:get-request-field("runsuiteteardown", "") eq "true"
  let $run-teardown as xs:boolean := xdmp:get-request-field("runteardown", "") eq "true"
  let $format as xs:string := xdmp:get-request-field("format", "xml")
  return
    if ($suite) then
      let $result := t:run-suite($suite, $tests, $run-suite-teardown, $run-teardown)
      return
        if ($format eq "junit") then
          local:format-junit($result)
        else
          $result
    else ()
};

declare function local:list()
{
  t:list()
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
          <h2>{$app-server} Unit Tests:&nbsp;<span id="passed-count"/><span id="failed-count"/></h2>

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
              <th>Test Suite</th>
              <th>Total Test Count</th>
              <th>Tests Run</th>
              <th>Passed</th>
              <th>Failed</th>
            </tr>
          </thead>

          <tbody>
          {
            for $suite at $index in t:list()/t:suite
            let $class := if ($index mod 2 = 1) then "odd" else "even"
            return
            (
              <tr class="{$class}">
                <td class="left"><input class="cb" type="checkbox" checked="checked" value="{fn:data($suite/@path)}"/></td>
                <td>
                  <div class="test-name">
                    <img class="tests-toggle-plus" src="img/arrow-right.gif"/>
                    <img class="tests-toggle-minus" src="img/arrow-down.gif"/>
                    {fn:data($suite/@path)} <span class="spinner"><img src="img/spinner.gif"/><b>Running...</b></span>
                  </div>

                </td>
                <td>{fn:count($suite/t:tests/t:test)}</td>
                <td class="tests-run">-</td>
                <td class="passed">-</td>
                <td class="right failed">-</td>
              </tr>,
              <tr class="{$class} tests">
                <td colspan="6">
                <div class="tests">
                  <div class="wrapper"><input class="check-all-tests" type="checkbox" checked="checked"/>Run All Tests</div>
                  <ul class="tests">
                  {
                    for $test in $suite/t:tests/t:test
                    return
                      <li class="tests">
                      {
                        if ($test/@path = "suite-setup.xqy" or $test/@path = "suite-teardown.xqy" or $test/@path = "suiteSetup.sjs" or $test/@path = "suiteTeardown.sjs") then
                          <input type="hidden" value="{fn:data($test/@path)}"/>
                        else
                          <input class="test-cb" type="checkbox" checked="checked" value="{fn:data($test/@path)}"/>,
                        fn:string($test/@path)
                      }<span class="outcome"></span>
                      </li>
                  }
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
              <td><label for="runsuiteteardown">Run Teardown after each suite</label><input id="runsuiteteardown" type="checkbox" checked="checked"/></td>
            </tr>
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
