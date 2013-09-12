xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

declare option xdmp:mapping "false";

declare function t:test-1()
{
  t:assert-true(fn:false())
};

declare function t:test-2()
{
  t:assert-true(fn:false())
};

declare function t:test-3()
{
  t:assert-true(fn:false())
};

declare function t:setup()
{
  "setup baby!"
};

declare function t:teardown()
{
  "teardown baby!"
};

