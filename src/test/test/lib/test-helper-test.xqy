xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

declare option xdmp:mapping "false";

declare function t:assert-all-exist()
{
  let $case1 := function() {
    t:assert-all-exist(1, (<a/>, <b/>, <c/>))
  }

  let $case2 := function() {
    t:assert-all-exist(4, (<a/>, <b/>, <c/>))
  }
  return
  (
    t:assert-all-exist(0, ()),
    t:assert-all-exist(1, "1"),
    t:assert-all-exist(2, ("1", "2")),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2)
  )
};

declare function t:asset-at-least-one-equal()
{
  let $case1 := function() {
    t:assert-at-least-one-equal((0, 1, 2), 4)
  }

  let $case2 := function() {
    t:assert-at-least-one-equal(4, (0, 1, 2))
  }

  let $case3 := function() {
    t:assert-at-least-one-equal((0, 1, 2), (4, 5, 6))
  }

  let $case4 := function() {
    t:assert-at-least-one-equal((), ())
  }

  return
  (
    t:assert-at-least-one-equal(0, 0),
    t:assert-at-least-one-equal(0, (0, 1, 2)),
    t:assert-at-least-one-equal((0, 1, 2), 0),
    t:assert-at-least-one-equal((0, 1, 2), (0, 3, 4)),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2),
    t:assert-throws-error($case3),
    t:assert-throws-error($case4)
  )
};

declare function t:assert-equal()
{
  let $case1 := function() {
    t:assert-equal(<a class="1"/>, <g class="2"/>)
  }

  let $case2 := function() {
    t:assert-equal((<a/>, <b/>, <c/>), (<a/>, <b/>))
  }

  let $case3 := function() {
    t:assert-equal((<a/>, <b/>), (<a/>, <b/>, <c/>))
  }

  let $case4 := function() {
    t:assert-equal((<a/>, <b/>, <c/>), (<a/>, <c/>, <b/>))
  }

  let $case5 := function() {
    t:assert-equal((<a><aa/></a>, <b/>, <c/>), (element a { element aaa { } }, element b {}, element c {}))
  }

  return
  (
    t:assert-throws-error($case1),
    t:assert-equal(<a class="1"/>, element a { attribute class { "1" } }),
    t:assert-throws-error($case2),
    t:assert-throws-error($case3),
    t:assert-throws-error($case4),
    t:assert-equal((<a/>, <b/>, <c/>), (<a/>, <b/>, <c/>)),
    t:assert-equal((<a/>, <b/>, <c/>), (element a {}, element b {}, element c {})),
    t:assert-equal((<a><aa/></a>, <b/>, <c/>), (element a { element aa { } }, element b {}, element c {})),
    t:assert-equal(5, 5),
    t:assert-equal("a", "a"),
    t:assert-equal((), ()),
    t:assert-throws-error($case5)
  )
};

declare function t:assert-exists()
{
  let $case1 := function() {
    t:assert-exists(())
  }
  return
  (
    t:assert-exists("1"),
    t:assert-exists(("1", "2")),
    t:assert-exists(<a/>),
    t:assert-throws-error($case1)
  )
};

declare function t:assert-false()
{
  let $case1 := function() {
    t:assert-false(fn:true())
  }

  let $case2 := function() {
    t:assert-false((fn:false(), fn:true()))
  }
  return
  (
    t:assert-false(fn:false()),
    t:assert-false((fn:false(), fn:false())),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2)
  )
};

declare function t:assert-meets-maximum-threshold()
{
  let $case1 := function() {
    t:assert-meets-maximum-threshold(6, 7)
  }

  let $case2 := function() {
    t:assert-meets-maximum-threshold(6, (5, 6, 7))
  }
  return
  (
    t:assert-meets-maximum-threshold(6, 6),
    t:assert-meets-maximum-threshold(6, (3, 4, 5, 6)),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2)
  )
};

declare function t:assert-meets-minimum-threshold()
{
  let $case1 := function() {
    t:assert-meets-minimum-threshold(2, 1)
  }

  let $case2 := function() {
    t:assert-meets-minimum-threshold(2, (1, 2, 3))
  }
  return
  (
    t:assert-meets-minimum-threshold(2, 2),
    t:assert-meets-minimum-threshold(2, (3, 4, 5, 6)),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2)
  )
};

declare function t:assert-not-equal()
{
  let $case1 := function() {
    t:assert-not-equal(0, 0)
  }

  let $case2 := function() {
    t:assert-not-equal(<a/>, <a/>)
  }
  return
  (
    t:assert-not-equal(0, 1),
    t:assert-not-equal((0, 1, 2), (0, 2, 1)),
    t:assert-not-equal((0, 1, 2), ()),
    t:assert-not-equal(<a/>, <g/>),
    t:assert-not-equal(<a><aa/></a>, <g/>),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2)
  )
};

declare function t:assert-not-exists()
{
  let $case1 := function() {
    t:assert-not-exists("a")
  }
  return
  (
    t:assert-not-exists(()),
    t:assert-throws-error($case1)
  )
};

declare function t:assert-throws-error()
{
  let $case1 := function() {
    5 div 0
  }

  let $case2 := function() {
    5 div 0
  }

  let $case3 := function() {
    5 div 0
  }

  let $case4 := function() {
    5 div 5
  }

  let $case5 := function($num) {
    $num div 0
  }

  return
  (
    t:assert-throws-error($case1),

    t:assert-throws-error($case2, "XDMP-DIVBYZERO"),

    try {
      t:assert-throws-error($case3, "XDMP-DIVBYZERO2"),
      t:fail("Did not Throw error and should have")
    }
    catch($ex) {
      if ($ex/error:name eq fn:string($FAIL)) then
        t:success()
      else
        t:fail($ex)
    },

    try {
      t:assert-throws-error($case4),
      t:fail("Did not Throw error and should have")
    }
    catch($ex) {
      if ($ex/error:name eq fn:string($FAIL)) then
        t:success()
      else
        t:fail($ex)
    },

    t:assert-throws-error($case5, 5, ()),

    t:assert-throws-error($case5, 5, "XDMP-DIVBYZERO")
  )
};

declare function t:assert-true()
{
  let $case1 := function() {
    t:assert-true(fn:false())
  }

  let $case2 := function() {
    t:assert-true((fn:true(), fn:false()))
  }

  let $case3 := function() {
    t:assert-true(fn:false(), "test")
  }

  let $case4 := function() {
    t:assert-true((fn:true(), fn:false()), "test")
  }
  return
  (
    t:assert-true(fn:true()),
    t:assert-true((fn:true(), fn:true())),
    t:assert-throws-error($case1),
    t:assert-throws-error($case2),

    t:assert-true(fn:true(), "test"),
    t:assert-true((fn:true(), fn:true()), "test"),
    t:assert-throws-error($case3),
    t:assert-throws-error($case4)
  )
};

declare function t:fail-test()
{
  let $case1 := function() {
    t:fail('i failed')
  }
  return
    t:assert-throws-error($case1)
};

declare function t:success-test()
{
  t:assert-equal(<t:assertion type="success"/>, t:success())
};

declare function t:get-test-file()
{
  let $setup := function() {
    t:load-test-file(
      "test.xml",
      xdmp:database(),
      "/test.xml"),
    t:load-test-file(
      "test.docx",
      xdmp:database(),
      "/test.docx"),
    t:load-test-file(
      "test.xqy",
      xdmp:database(),
      "/test.xqy"),
    t:load-test-file(
      "test.bin",
      xdmp:database(),
      "/test.bin")
  }

  let $test := function() {
    t:assert-equal("element", xdmp:node-kind(fn:doc("/test.xml")/node())),
    t:assert-equal("binary", xdmp:node-kind(fn:doc("/test.docx")/node())),
    t:assert-equal("text", xdmp:node-kind(fn:doc("/test.xqy")/node())),
    t:assert-equal("binary", xdmp:node-kind(fn:doc("/test.bin")/node()))
  }

  let $teardown := function() {
    xdmp:eval('
      xdmp:document-delete("/test.xml"),
      xdmp:document-delete("/test.docx"),
      xdmp:document-delete("/test.xqy"),
      xdmp:document-delete("/test.bin")
    ')
  }
  return
  (
    xdmp:invoke-function($setup),
    xdmp:invoke-function($test),
    xdmp:invoke-function($teardown)
  )
};