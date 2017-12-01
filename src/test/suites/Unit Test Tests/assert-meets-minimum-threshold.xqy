import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace tlib = "http://marklogic.com/roxy/unit-test-tests" at "lib/testing-lib.xqy";

declare function local:case1()
{
  test:assert-meets-minimum-threshold(2, 1)
};

declare function local:case2()
{
  test:assert-meets-minimum-threshold(2, (1, 2, 3))
};

test:assert-meets-minimum-threshold(2, 2),
test:assert-meets-minimum-threshold(2, (3, 4, 5, 6)),
tlib:test-for-failure(local:case1(), "ASSERT-MEETS-MINIMUM-THRESHOLD-FAILED"),
tlib:test-for-failure(local:case2(), "ASSERT-MEETS-MINIMUM-THRESHOLD-FAILED")
