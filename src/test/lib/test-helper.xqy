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

module namespace t="http://marklogic.com/roxy/test";

import module namespace cvt = "http://marklogic.com/cpf/convert" at "/MarkLogic/conversion/convert.xqy";

declare namespace ss="http://marklogic.com/xdmp/status/server";
declare namespace xdmp-http="xdmp:http";

declare variable $FAIL := xs:QName("TEST-FAIL");

declare option xdmp:mapping "false";

declare variable $t:PREVIOUS_LINE_FILE as xs:string :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    fn:concat($ex/error:stack/error:frame[3]/error:uri, " : Line ", $ex/error:stack/error:frame[3]/error:line)
  };

declare variable $t:__LINE__ as xs:int :=
  try {
   fn:error(xs:QName("boom"), "")
  }
  catch($ex) {
    $ex/error:stack/error:frame[2]/error:line
  };

declare variable $t:__CALLER_FILE__  := t:get-caller();

declare function t:get-caller()
as xs:string
{
  try { fn:error((), "ROXY-BOOM") }
  catch ($ex) {
    if ($ex/error:code ne 'ROXY-BOOM') then xdmp:rethrow()
    else (
      let $uri-list := $ex/error:stack/error:frame/error:uri/fn:string()
      let $this := $uri-list[1]
      return (($uri-list[. ne $this])[1], 'no file')[1])
   }
};

declare function t:get-test-file($filename as xs:string)
as document-node()
{
  t:get-modules-file(
    fn:replace(
      fn:concat(
        cvt:basepath($t:__CALLER_FILE__), "/data/", $filename),
      "//", "/"))
};

declare function t:load-test-file($filename as xs:string, $database-id as xs:unsignedLong, $uri as xs:string)
{
 if ($database-id eq 0) then
    let $uri := fn:replace($uri, "//", "/")
    let $_ :=
      try {
        xdmp:filesystem-directory(cvt:basepath($uri))
      }
      catch($ex) {
        xdmp:filesystem-directory-create(cvt:basepath($uri),
                    <options xmlns="xdmp:filesystem-directory-create">
                      <create-parents>true</create-parents>
                    </options>)
      }
    return
      xdmp:save($uri, t:get-test-file($filename))
  else
    xdmp:eval('
      xquery version "1.0-ml";

      declare variable $uri as xs:string external;
      declare variable $file as node() external;
      xdmp:document-insert($uri, $file)
    ',
    (xs:QName("uri"), $uri,
     xs:QName("file"), t:get-test-file($filename)),
    <options xmlns="xdmp:eval">
      <database>{$database-id}</database>
    </options>)
};

declare function t:build-uri(
  $base as xs:string,
  $suffix as xs:string) as xs:string
{
  fn:string-join(
    (fn:replace($base, "(.*)/$", "$1"),
     fn:replace($suffix, "^/(.*)", "$1")),
    "/")
};

declare function t:get-modules-file($file as xs:string)
{
  if (xdmp:modules-database() eq 0) then
    let $doc :=
      xdmp:document-get(
        t:build-uri(xdmp:modules-root(), $file),
        <options xmlns="xdmp:document-get">
          <format>text</format>
        </options>)
    return
      try {
        xdmp:unquote($doc)
      }
      catch($ex) {$doc}
  else
  (
    let $doc := xdmp:eval(
      'declare variable $file as xs:string external; fn:doc($file)',
      (xs:QName('file'), $file),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
      </options>)
    return
      if ($doc/*) then
        $doc
      else
        try {
          xdmp:unquote($doc) (: TODO WTF? :)
        }
        catch($ex) {
          $doc
        }
  )
};

(:~
 : constructs a success xml element
 :)
declare function t:success()
{
  <t:assertion type="success"/>
};

(:~
 : constructs a failure xml element
 :)
declare function t:fail($expected as item(), $actual as item())
{
  t:fail(<oh-nos>Expected {$expected} but got {$actual} at {$t:PREVIOUS_LINE_FILE}</oh-nos>)
};

(:~
 : constructs a failure xml element
 :)
declare function t:fail($message as item()*)
{
  fn:error($FAIL, $message)
};

declare function t:assert-all-exist($count as xs:unsignedInt, $item as item()*)
{
  if ($count eq fn:count($item)) then
    t:success()
  else
    fn:error($FAIL, "Assert All Exist failed", $item)
};

declare function t:assert-exists($item as item()*)
{
  if (fn:exists($item)) then
    t:success()
  else
    fn:error($FAIL, "Assert Exists failed", $item)
};

declare function t:assert-not-exists($item as item()*)
{
  if (fn:not(fn:exists($item))) then
    t:success()
  else
    fn:error($FAIL, "Assert Not Exists failed", $item)
};

declare function t:assert-at-least-one-equal($expected as item()*, $actual as item()*)
{
  if ($expected = $actual) then
    t:success()
  else
    fn:error($FAIL, "Assert At Least one Equal failed", ())
};

declare private function t:are-these-equal($expected as item()*, $actual as item()*)
{
  if (fn:count($expected) eq fn:count($actual)) then
    fn:count((for $item at $i in $expected
    return
      fn:deep-equal($item, $actual[$i]))[. = fn:true()]) eq fn:count($expected)
  else
    fn:false()
};

(: Return true if and only if the two sequences have the same values, regardless
 : of order. fn:deep-equal() returns false if items are not in the same order. :)
declare function t:assert-same-values($expected as item()*, $actual as item()*)
{
  let $expected-ordered :=
    for $e in $expected
    order by $e
    return $e
  let $actual-ordered :=
    for $a in $actual
    order by $a
    return $a
  return t:assert-equal($expected-ordered, $actual-ordered)
};

declare function t:assert-equal($expected as item()*, $actual as item()*)
{
  if (t:are-these-equal($expected, $actual)) then
    t:success()
  else
    fn:error($FAIL, "Assert Equal failed", (xdmp:quote($expected), xdmp:quote($actual)))
};

declare function t:assert-not-equal($expected as item()*, $actual as item()*)
{
  if (fn:not(t:are-these-equal($expected, $actual))) then
    t:success()
  else
    fn:error(
      $FAIL,
      fn:concat("test name", ": Assert Not Equal failed"),
      ($expected, $actual))
};

declare function t:assert-true($supposed-truths as xs:boolean*)
{
  t:assert-true($supposed-truths, $supposed-truths)
};

declare function t:assert-true($supposed-truths as xs:boolean*, $msg as item()*)
{
  if (fn:false() = $supposed-truths) then
    fn:error($FAIL, "Assert True failed", $msg)
  else
    t:success()
};

declare function t:assert-false($supposed-falsehoods as xs:boolean*)
{
  if (fn:true() = $supposed-falsehoods) then
    fn:error($FAIL, "Assert False failed", $supposed-falsehoods)
  else
    t:success()
};


declare function t:assert-meets-minimum-threshold($expected as xs:decimal, $actual as xs:decimal+)
{
  if (every $i in 1 to fn:count($actual) satisfies $actual[$i] ge $expected) then
    t:success()
  else
    fn:error(
      $FAIL,
      fn:concat("test name", ": Assert Meets Minimum Threshold failed"),
      ($expected, $actual))
};

declare function t:assert-meets-maximum-threshold($expected as xs:decimal, $actual as xs:decimal+)
{
  if (every $i in 1 to fn:count($actual) satisfies $actual[$i] le $expected) then
    t:success()
  else
    fn:error(
      $FAIL,
      fn:concat("test name", ": Assert Meets Maximum Threshold failed"),
      ($expected, $actual))
};

declare function t:assert-throws-error($f as function(*))
{
  t:assert-throws-error($f, ())
};

declare function t:assert-throws-error($f as function(*), $error-code as xs:string?)
{
  t:assert-throws-error($f, (), $error-code)
};

declare function t:assert-throws-error($f as function(*), $params as item()*, $error-code as xs:string?)
{
  try
  {
    if (fn:exists($params)) then
      $f($params)
    else
      $f(),
    fn:error(xs:QName("ASSERT-THROWS-ERROR-FAILED"), "It did not throw an error")
  }
  catch($ex)
  {
    if ($ex/error:name eq "ASSERT-THROWS-ERROR-FAILED") then
      fn:error($FAIL, "It did not throw an error")
    else if ($error-code) then
      if ($ex/error:code eq $error-code or $ex/error:name eq $error-code) then
        t:success()
      else
      (
        fn:error($FAIL, fn:concat("Error code was: ", $ex/error:code, " not: ", $error-code))
      )
    else
      t:success()
  }
};

declare function t:easy-url($url) as xs:string
{
  if (fn:starts-with($url, "http")) then $url
  else
    fn:concat("http://localhost:", fn:tokenize(xdmp:get-request-header("Host"), ":")[2], if (fn:starts-with($url, "/")) then () else "/", $url)
};

declare function t:http-get($url as xs:string, $options as node()?)
{
  let $uri :=
    if (fn:starts-with($url, "http")) then $url
    else
      fn:concat("http://localhost:", fn:tokenize(xdmp:get-request-header("Host"), ":")[2], if (fn:starts-with($url, "/")) then () else "/", $url)
  return
    xdmp:http-get($uri, $options)
};

declare function t:assert-http-get-status($url as xs:string, $options as element(xdmp-http:options), $status-code)
{
  let $response := t:http-get($url, $options)
  return
    t:assert-equal($status-code, fn:data($response[1]/*:code))
};

(:~
 : Convenience function to remove all xml docs from the data db
 :)
declare function t:delete-all-xml()
{
  xdmp:eval('for $x in (cts:uri-match("*.xml"), cts:uri-match("*.xlsx"))
             where fn:not(fn:contains($x, "config/config.xml"))
             return
              try {xdmp:document-delete($x)}
              catch($ex) {()}')
};

declare function t:wait-for-doc($pattern, $sleep)
{
  if (xdmp:eval(fn:concat("cts:uri-match('", $pattern, "')"))) then ()
  else
  (
    xdmp:sleep($sleep),
    t:wait-for-doc($pattern, $sleep)
  )
};

declare function t:wait-for-truth($truth as xs:string, $sleep)
{
  if (xdmp:eval($truth)) then ()
  else
  (
    xdmp:sleep($sleep),
    t:wait-for-truth($truth, $sleep)
  )
};

declare function t:wait-for-taskserver($sleep)
{
  (: do the sleep first. on some super awesome computers the check for active
     tasks can return 0 before they have a change to queue up :)
  xdmp:log(fn:concat("Waiting ", $sleep, " msec for taskserver..")),
  xdmp:sleep($sleep),

  let $group-servers := xdmp:group-servers(xdmp:group())
  let $task-server := xdmp:server("TaskServer")[. = $group-servers]
  let $status := xdmp:server-status(xdmp:host(), $task-server)
  let $queue-size as xs:unsignedInt := $status/ss:queue-size
  let $active-requests as xs:unsignedInt := fn:count($status/ss:request-statuses/ss:request-status)
  return
    if ($queue-size = 0 and $active-requests = 0) then
      xdmp:log("Done waiting for taskserver!")
    else
      t:wait-for-taskserver($sleep)
};

(:~
 : Convenience function to invoke a sleep
 :)
declare function t:sleep($msec as xs:unsignedInt) as empty-sequence()
{
  xdmp:eval('declare variable $msec as xs:unsignedInt external;
             xdmp:sleep($msec)',
            (xs:QName("msec"), $msec))
};