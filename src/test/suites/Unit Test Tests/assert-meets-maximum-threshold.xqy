import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  test:assert-meets-maximum-threshold(6, 7)
};

declare function local:case2()
{
  test:assert-meets-maximum-threshold(6, (5, 6, 7))
};

test:assert-meets-maximum-threshold(6, 6),
test:assert-meets-maximum-threshold(6, (3, 4, 5, 6)),
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-MEETS-MAXIMUM-THRESHOLD-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-MEETS-MAXIMUM-THRESHOLD-FAILED")