import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

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
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-TRUE-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-TRUE-FAILED"),

test:assert-true(fn:true(), "test"),
test:assert-true((fn:true(), fn:true()), "test"),
test:assert-throws-error(xdmp:function(xs:QName("local:case3")), "ASSERT-TRUE-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case4")), "ASSERT-TRUE-FAILED")