xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

declare option xdmp:mapping "false";

declare function t:build-uri()
{
  t:assert-equal("base/suffix", u:build-uri("base", "suffix")),
  t:assert-equal("base/suffix", u:build-uri("base", "/suffix")),
  t:assert-equal("base/suffix", u:build-uri("base/", "suffix")),
  t:assert-equal("base/suffix", u:build-uri("base/", "/suffix")),
  t:assert-equal("/app/views/tester/main.json.xqy", u:build-uri("/", "/app/views/tester/main.json.xqy"))
};

declare function t:join-file()
{
  t:assert-equal("base/suffix", u:join-file(("base", "suffix"))),
  t:assert-equal("base/suffix", u:join-file(("base", "/suffix"))),
  t:assert-equal("base/suffix", u:join-file(("base/", "suffix"))),
  t:assert-equal("base/suffix", u:join-file(("base/", "/suffix"))),
  t:assert-equal("/app/views/tester/main.json.xqy", u:join-file(("/", "/app/views/tester/main.json.xqy"))),

  t:assert-equal("/base/suffix", u:join-file(("/base/", "suffix"))),
  t:assert-equal("/base/suffix", u:join-file(("/base", "/suffix"))),
  t:assert-equal("/base/suffix", u:join-file(("/base/", "/suffix"))),
  t:assert-equal("/base/suffix/", u:join-file(("/base/", "suffix/"))),
  t:assert-equal("/base/suffix/", u:join-file(("/base", "/suffix/"))),
  t:assert-equal("/base/suffix/", u:join-file(("/base/", "/suffix/")))
};

declare function t:string-pad()
{
  t:assert-equal("000", u:string-pad("0", 3))
};

declare function t:lead-zero()
{
  t:assert-equal("00001", u:lead-zero("1", 5)),
  t:assert-equal("123", u:lead-zero("123", 3))
};