xquery version "1.0-ml";

import module namespace c = "http://marklogic.com/ns/test-config" at "/test/test-config.xqy";
import module namespace helper="http://marklogic.com/ps/test-helper" at "/test/test-helper.xqy";

declare namespace test = "http://marklogic.com/ps/test";

declare option xdmp:mapping "false";

declare variable $options :=
  <options xmlns="xdmp:http">
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
    <format xmlns="xdmp:document-get">xml</format>
  </options>;

let $uri := 
  fn:concat(
    "/test-request/test1?",
    "valid=yes",
    "&amp;dt=", fn:current-dateTime(),
    "&amp;number=1234",
    "&amp;invalidnumber=notnum",
    "&amp;single=val1",
    "&amp;single=val2",
    "&amp;sequence=a",
    "&amp;sequence=b",
    "&amp;sequence=c",
    "&amp;hasquote=", fn:encode-for-uri("has""quote""indeed"),
    "&amp;x1=<test/>",
    "&amp;x2=<<busted-xml/>",
    "&amp;empty=")
let $response := helper:http-get($uri, $options)
return
  $response[2]/*:results/*