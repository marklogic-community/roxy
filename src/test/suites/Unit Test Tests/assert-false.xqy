import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-false(fn:true())
};

declare function local:case2()
{
  test:assert-false((fn:false(), fn:true()))
};

test:assert-false(fn:false()),
test:assert-false((fn:false(), fn:false())),
tlib:test-for-failure(local:case1(), "ASSERT-FALSE-FAILED"),
tlib:test-for-failure(local:case2(), "ASSERT-FALSE-FAILED")
