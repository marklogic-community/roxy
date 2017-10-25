import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-exists(())
};

test:assert-exists("1"),
test:assert-exists(("1", "2")),
test:assert-exists(<a/>),
tlib:test-for-failure(local:case1(), "ASSERT-EXISTS-FAILED")
