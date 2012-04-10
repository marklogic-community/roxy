import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  test:assert-exists(())
};

test:assert-exists("1"),
test:assert-exists(("1", "2")),
test:assert-exists(<a/>),
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-EXISTS-FAILED")