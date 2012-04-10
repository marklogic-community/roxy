import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  test:assert-equal(<a class="1"/>, <g class="2"/>)
};

declare function local:case2()
{
  test:assert-equal((<a/>, <b/>, <c/>), (<a/>, <b/>))
};

declare function local:case3()
{
  test:assert-equal((<a/>, <b/>), (<a/>, <b/>, <c/>))
};

declare function local:case4()
{
  test:assert-equal((<a/>, <b/>, <c/>), (<a/>, <c/>, <b/>))
};

declare function local:case5()
{
  test:assert-equal((<a><aa/></a>, <b/>, <c/>), (element a { element aaa { } }, element b {}, element c {}))
};

test:assert-throws-error(xdmp:function(xs:QName("local:case1")), "ASSERT-EQUAL-FAILED"),

test:assert-equal(<a class="1"/>, element a { attribute class { "1" } }),

test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "ASSERT-EQUAL-FAILED"),

test:assert-throws-error(xdmp:function(xs:QName("local:case3")), "ASSERT-EQUAL-FAILED"),

test:assert-throws-error(xdmp:function(xs:QName("local:case4")), "ASSERT-EQUAL-FAILED"),

test:assert-equal((<a/>, <b/>, <c/>), (<a/>, <b/>, <c/>)),

test:assert-equal((<a/>, <b/>, <c/>), (element a {}, element b {}, element c {})),

test:assert-equal((<a><aa/></a>, <b/>, <c/>), (element a { element aa { } }, element b {}, element c {})),

test:assert-equal(5, 5),

test:assert-equal("a", "a"),

test:assert-equal((), ()),

test:assert-throws-error(xdmp:function(xs:QName("local:case5")), "ASSERT-EQUAL-FAILED")