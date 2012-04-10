import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  test:assert-at-least-one-equal((0, 1, 2), 4)
};

declare function local:case2()
{
  test:assert-at-least-one-equal(4, (0, 1, 2))
};

declare function local:case3()
{
  test:assert-at-least-one-equal((0, 1, 2), (4, 5, 6))
};

declare function local:case4()
{
  test:assert-at-least-one-equal((), ())
};

test:assert-at-least-one-equal(0, 0),
test:assert-at-least-one-equal(0, (0, 1, 2)),
test:assert-at-least-one-equal((0, 1, 2), 0),
test:assert-at-least-one-equal((0, 1, 2), (0, 3, 4)),
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-AT-LEAST-ONE-EQUAL-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-AT-LEAST-ONE-EQUAL-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case3")), "ASSERT-AT-LEAST-ONE-EQUAL-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case4")), "ASSERT-AT-LEAST-ONE-EQUAL-FAILED")
