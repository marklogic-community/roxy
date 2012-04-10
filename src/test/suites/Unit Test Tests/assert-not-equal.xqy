import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  test:assert-not-equal(0, 0)
};

declare function local:case2()
{
  test:assert-not-equal(<a/>, <a/>)
};

test:assert-not-equal(0, 1),
test:assert-not-equal((0, 1, 2), (0, 2, 1)),
test:assert-not-equal((0, 1, 2), ()),
test:assert-not-equal(<a/>, <g/>),
test:assert-not-equal(<a><aa/></a>, <g/>),
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-NOT-EQUAL-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-NOT-EQUAL-FAILED")