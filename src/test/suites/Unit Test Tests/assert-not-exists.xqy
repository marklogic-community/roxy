import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-not-exists("a")
};

test:assert-not-exists(()),
tlib:test-for-failure(local:case1(), "ASSERT-NOT-EXISTS-FAILED")
