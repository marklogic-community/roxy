import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

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
tlib:test-for-failure(local:case1(), "ASSERT-NOT-EQUAL-FAILED"),
tlib:test-for-failure(local:case2(), "ASSERT-NOT-EQUAL-FAILED")
