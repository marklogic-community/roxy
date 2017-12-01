import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-all-exist(1, (<a/>, <b/>, <c/>))
};

declare function local:case2()
{
  test:assert-all-exist(4, (<a/>, <b/>, <c/>))
};

test:assert-all-exist(0, ()),
test:assert-all-exist(1, "1"),
test:assert-all-exist(2, ("1", "2")),

tlib:test-for-failure(local:case1(), "ASSERT-ALL-EXIST-FAILED"),
tlib:test-for-failure(local:case2(), "ASSERT-ALL-EXIST-FAILED")
