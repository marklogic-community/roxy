import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

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
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-FALSE-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-FALSE-FAILED")