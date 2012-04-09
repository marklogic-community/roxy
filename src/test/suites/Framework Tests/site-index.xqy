xquery version "1.0-ml";

import module namespace test="http://marklogic.com/ps/test-helper" at "/test/test-helper.xqy";

import module namespace c = "http://marklogic.com/ns/test-config" at "/test/test-config.xqy";

let $options :=
  <options xmlns="xdmp:http">
    <format xmlns="xdmp:document-get">xml</format>
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
  </options>
let $response := xdmp:http-get(test:easy-url("/"), $options)
return
(
  test:assert-equal(fn:data($response[1]/*:code), 200),
  test:assert-equal(1, fn:count($response[2]//*:html))
)