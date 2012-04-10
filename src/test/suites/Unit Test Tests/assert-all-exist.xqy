import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

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
test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-ALL-EXIST-FAILED"),
test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-ALL-EXIST-FAILED")