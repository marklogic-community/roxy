xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace form = "http://marklogic.com/roxy/form-lib" at "/app/views/helpers/form-lib.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

let $input := form:text-area("input-label", "input-name", "input-class")
return (
  test:assert-equal("input-label", $input/html:label/fn:string()),
  test:assert-equal("input-name", $input/html:textarea/@name/fn:string()),
  test:assert-equal("input-class", $input/@class/fn:string()),
  test:assert-equal("", $input/html:textarea/fn:string())
),

let $input := form:text-area("input-label", "input-name", "input-class", "input-value")
return (
  test:assert-equal("input-label", $input/html:label/fn:string()),
  test:assert-equal("input-name", $input/html:textarea/@name/fn:string()),
  test:assert-equal("input-class", $input/@class/fn:string()),
  test:assert-equal("input-value", $input/html:textarea/fn:string())
)
