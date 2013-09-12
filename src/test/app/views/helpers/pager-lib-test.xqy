xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace pager = "http://marklogic.com/roxy/pager-lib" at "/app/views/helpers/pager-lib.xqy";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare function t:next-page()
{
  t:assert-not-exists(pager:next-page(1, 10, 3, "", "")),

  let $actual := pager:next-page(11, 10, 50, "/search", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=21", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:next-page(21, 10, 50, "/search?a=b", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?a=b&amp;index=31", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:next-page(21, 10, 50, "/search?index=21&amp;a=b", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=31&amp;a=b", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:next-page(21, 10, 50, "/search?a=b&amp;index=21", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?a=b&amp;index=31", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:next-page(21, 10, 50, "/search?index=21", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=31", $actual/xhtml:a/@href/fn:string())
  )
};

declare function t:previous-page()
{
  t:assert-not-exists(pager:previous-page(1, 10, 50, "", "")),

  let $actual := pager:previous-page(11, 10, 50, "/search", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=1", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:previous-page(21, 10, 50, "/search?a=b", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?a=b&amp;index=11", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:previous-page(21, 10, 50, "/search?index=21&amp;a=b", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=11&amp;a=b", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:previous-page(21, 10, 50, "/search?a=b&amp;index=21", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?a=b&amp;index=11", $actual/xhtml:a/@href/fn:string())
  ),

  let $actual := pager:previous-page(21, 10, 50, "/search?index=21", "index")
  return (
    t:assert-exists($actual/xhtml:a),
    t:assert-equal("/search?index=11", $actual/xhtml:a/@href/fn:string())
  )
};

declare function t:show-page-numbers()
{
  t:assert-equal(
    "Results 11 to 20 of 50",
    fn:string(pager:show-page-numbers(11, 10, 50))),

  t:assert-equal(
    "Results 11 to 15 of 15",
    fn:string(pager:show-page-numbers(11, 10, 15)))
};
