import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-true(fn:false())
};

declare function local:case2()
{
  test:assert-true((fn:true(), fn:false()))
};

declare function local:case3()
{
  test:assert-true(fn:false(), "test")
};

declare function local:case4()
{
  test:assert-true((fn:true(), fn:false()), "test")
};

test:assert-true(fn:true()),
test:assert-true((fn:true(), fn:true())),
tlib:test-for-failure(local:case1(), "ASSERT-TRUE-FAILED"),
tlib:test-for-failure(local:case2(), "ASSERT-TRUE-FAILED"),

test:assert-true(fn:true(), "test"),
test:assert-true((fn:true(), fn:true()), "test"),
tlib:test-for-failure(local:case3(), "ASSERT-TRUE-FAILED"),
tlib:test-for-failure(local:case4(), "ASSERT-TRUE-FAILED")
