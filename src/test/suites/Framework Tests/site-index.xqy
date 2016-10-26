xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";

(:
 : Each of the URLs being tested here includes the language parameter, because
 : the controllers can be implemented in either XQuery or SJS. The default is
 : controlled by a property. In order to avoid false negatives, these tests
 : make that choice explicit.
 :)
declare variable $LANG-XQY := "language=xqy";

let $options :=
  <options xmlns="xdmp:http">
    <format xmlns="xdmp:document-get">xml</format>
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
  </options>
let $response := test:http-get(test:easy-url("/?" || $LANG-XQY), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal(1, fn:count($response[2]//*:html))
)
