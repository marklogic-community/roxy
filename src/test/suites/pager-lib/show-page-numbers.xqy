xquery version "1.0-ml";

import module namespace pager = "http://marklogic.com/roxy/pager-lib" at "/app/views/helpers/pager-lib.xqy";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare namespace search = "http://marklogic.com/appservices/search";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

let $actual :=
  pager:show-page-numbers(11, 10, 50)
return (
  test:assert-equal(
    "Results 11 to 20 of 50",
    fn:string($actual))
),

let $actual :=
  pager:show-page-numbers(11, 10, 15)
return (
  test:assert-equal(
    "Results 11 to 15 of 15",
    fn:string($actual))
)

