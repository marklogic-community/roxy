xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace form = "http://marklogic.com/roxy/form-lib" at "/app/views/helpers/form-lib.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

let $cb := form:checkbox("cb-label", "cb-name", fn:true(), "cb-class", "cb-id")
return (
  test:assert-equal("cb-label", $cb/html:label/fn:string()),
  test:assert-equal("cb-name", $cb/html:input/@name/fn:string()),
  test:assert-exists($cb/html:input/@checked),
  test:assert-equal("cb-class", $cb/@class/fn:string()),
  test:assert-equal("cb-id", $cb/html:label/@for/fn:string()),
  test:assert-equal("cb-id", $cb/html:input/@id/fn:string()),
  test:assert-equal("checkbox", $cb/html:input/@type/fn:string())
),

let $cb := form:checkbox("cb-label2", "cb-name2", fn:false(), "cb-class2", "cb-id2")
return (
  test:assert-equal("cb-label2", $cb/html:label/fn:string()),
  test:assert-equal("cb-name2", $cb/html:input/@name/fn:string()),
  test:assert-not-exists($cb/html:input/@checked),
  test:assert-equal("cb-class2", $cb/@class/fn:string()),
  test:assert-equal("cb-id2", $cb/html:label/@for/fn:string()),
  test:assert-equal("cb-id2", $cb/html:input/@id/fn:string()),
  test:assert-equal("checkbox", $cb/html:input/@type/fn:string())
)

