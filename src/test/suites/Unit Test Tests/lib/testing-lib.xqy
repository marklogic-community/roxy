xquery version "1.0-ml";

module namespace tlib = "http://marklogic.com/roxy/unit-test-tests";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare option xdmp:mapping "false";

(:
 : Call a function and verify that a function generates the failure XML.
 :)
declare function tlib:test-for-failure($actual, $error-name as xs:string?)
{
  test:assert-equal("{http://marklogic.com/roxy/test}result", xdmp:key-from-QName(fn:node-name($actual))),
  test:assert-equal("fail", $actual/@type/fn:string()),
  if ($error-name) then
    test:assert-equal($error-name, $actual/error:error/error:name/fn:string())
  else ()
};

