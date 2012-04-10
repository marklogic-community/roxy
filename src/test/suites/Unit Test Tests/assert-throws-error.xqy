import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:case1()
{
  5 div 0
};

declare function local:case2()
{
  5 div 0
};

declare function local:case3()
{
  5 div 0
};

declare function local:case4()
{
  5 div 5
};

declare function local:case5($num)
{
  $num div 0
};

test:assert-throws-error(xdmp:function(xs:QName("local:case1"))),

test:assert-throws-error(xdmp:function(xs:QName("local:case2")), "XDMP-DIVBYZERO"),

try {
  test:assert-throws-error(xdmp:function(xs:QName("local:case3")), "XDMP-DIVBYZERO2"),
  test:fail("Did not Throw error and should have")
}
catch($ex) {
  if ($ex/error:name eq "ASSERT-THROWS-ERROR-FAILED") then
    test:success()
  else
    test:fail($ex)
},

try {
  test:assert-throws-error(xdmp:function(xs:QName("local:case4"))),
  test:fail("Did not Throw error and should have")
}
catch($ex) {
  if ($ex/error:name eq "ASSERT-THROWS-ERROR-FAILED") then
    test:success()
  else
    test:fail($ex)
},

test:assert-throws-error(xdmp:function(xs:QName("local:case5")), 5, ()),

test:assert-throws-error(xdmp:function(xs:QName("local:case5")), 5, "XDMP-DIVBYZERO")