xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module namespace m="http://marklogic.com/roxy/test-runner" at "/test/lib/test-runner.xqy";
import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

declare option xdmp:mapping "false";

declare function t:list()
{
  t:assert-same-values(
    (
      fn:concat(xdmp:modules-root(), "test/test/lib/data/funky-functions.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/all-fail.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/all-pass.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/one-failure.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-failure.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-noteardown.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-teardown.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/teardown-failure.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/test.xqy"),
      fn:concat(xdmp:modules-root(), "test/test/lib/data/two-failure.xqy")
    ),
    m:list(fn:concat(xdmp:modules-root(), "test/test/lib/data/"), ".xqy")/t:test/@path/fn:string(.))
};

declare function t:get-test-functions()
{
  t:assert-same-values(
    (
      "test-1",
      "test-2",
      "test-3",
      "setup",
      "teardown"
    ),
    m:get-test-functions(fn:concat(xdmp:modules-root(), "test/test/lib/data/one-failure.xqy")))
};

declare function t:get-test-functions-funky()
{
  t:assert-same-values(
    (
      "test-1",
      "test-3",
      "setup",
      "teardown"
    ),
    m:get-test-functions(fn:concat(xdmp:modules-root(), "test/test/lib/data/funky-functions.xqy")))
};

declare function t:all-tests-pass()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/all-pass.xqy"))
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("all-pass.xqy", fn:string($results/@name)),
    t:assert-equal(3, xs:int($results/@assertions)),
    t:assert-equal(0, xs:int($results/@failures)),
    t:assert-equal(0, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-true($results instance of element(t:test)),
    t:assert-equal(3, fn:count($results/t:assertion)),
    t:assert-equal(0, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(3, fn:count($results/t:assertion[@type='success'])),
    t:assert-equal(0, fn:count($results/t:error))
  )
};


declare function t:one-failure()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/one-failure.xqy"))
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("one-failure.xqy", fn:string($results/@name)),
    t:assert-equal(3, xs:int($results/@assertions)),
    t:assert-equal(1, xs:int($results/@failures)),
    t:assert-equal(0, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-true($results instance of element(t:test)),
    t:assert-equal(3, fn:count($results/t:assertion)),
    t:assert-equal(1, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(2, fn:count($results/t:assertion[@type='success'])),
    t:assert-equal(0, fn:count($results/t:error))
  )
};

declare function t:two-failure()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/two-failure.xqy"))
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("two-failure.xqy", fn:string($results/@name)),
    t:assert-equal(3, xs:int($results/@assertions)),
    t:assert-equal(2, xs:int($results/@failures)),
    t:assert-equal(0, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-true($results instance of element(t:test)),
    t:assert-equal(3, fn:count($results/t:assertion)),
    t:assert-equal(2, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(1, fn:count($results/t:assertion[@type='success'])),
    t:assert-equal(0, fn:count($results/t:error))
  )
};

declare function t:setup-failure()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-failure.xqy"))
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("setup-failure.xqy", fn:string($results/@name)),
    t:assert-equal(0, xs:int($results/@assertions)),
    t:assert-equal(0, xs:int($results/@failures)),
    t:assert-equal(1, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-equal(0, fn:count($results/t:assertion)),
    t:assert-equal(1, fn:count($results/t:error[@name = 'setup'])),
    t:assert-equal(0, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(0, fn:count($results/t:assertion[@type='success'])),
    t:assert-equal(1, fn:count($results/t:error))
  )
};

declare function t:teardown-failure()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/teardown-failure.xqy"))
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("teardown-failure.xqy", fn:string($results/@name)),
    t:assert-equal(3, xs:int($results/@assertions)),
    t:assert-equal(0, xs:int($results/@failures)),
    t:assert-equal(1, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-equal(3, fn:count($results/t:assertion)),
    t:assert-equal(1, fn:count($results/t:error[@name = 'teardown'])),
    t:assert-equal(1, fn:count($results/t:error)),
    t:assert-equal(0, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(3, fn:count($results/t:assertion[@type='success']))
  )
};

declare function t:setup-teardown()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-teardown.xqy"))
  let $_ := xdmp:log($results)
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("setup-teardown.xqy", fn:string($results/@name)),
    t:assert-equal(1, xs:int($results/@assertions)),
    t:assert-equal(0, xs:int($results/@failures)),
    t:assert-equal(0, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-equal(1, fn:count($results/t:assertion)),
    t:assert-equal(0, fn:count($results/t:error)),
    t:assert-equal(0, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(1, fn:count($results/t:assertion[@type='success'])),
    t:assert-not-exists(fn:doc("/test-delme.xml"))
  )
};

declare function t:setup-noteardown()
{
  let $results := m:run-test(fn:concat(xdmp:modules-root(), "test/test/lib/data/setup-noteardown.xqy"))
  let $_ := xdmp:log($results)
  return
  (
    t:assert-equal(1, fn:count($results)),
    t:assert-equal("setup-noteardown.xqy", fn:string($results/@name)),
    t:assert-equal(1, xs:int($results/@assertions)),
    t:assert-equal(0, xs:int($results/@failures)),
    t:assert-equal(0, xs:int($results/@errors)),
    t:assert-exists($results/@time),
    t:assert-equal(1, fn:count($results/t:assertion)),
    t:assert-equal(0, fn:count($results/t:error)),
    t:assert-equal(0, fn:count($results/t:assertion[@type='failure'])),
    t:assert-equal(1, fn:count($results/t:assertion[@type='success'])),
    t:assert-exists(xdmp:eval('fn:doc("/test-delme-later.xml")'))
  )
};

declare function t:run-tests()
{
  let $results := m:run-tests(m:list(fn:concat(xdmp:modules-root(), "test/test/lib/data/"), ".xqy")/t:test/@path/fn:string(.))
  return
  (
    t:assert-equal(19, xs:int($results/@assertions)),
    t:assert-equal(13, xs:int($results/@successes)),
    t:assert-equal(6, xs:int($results/@failures)),
    t:assert-equal(2, xs:int($results/@errors)),
    t:assert-exists($results/@time)
  )
};

declare function t:teardown()
{
  xdmp:document-delete("/test-delme-later.xml")
};
