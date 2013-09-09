xquery version "1.0-ml";

module namespace m = "http://marklogic.com/roxy/test-runner";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace cvt = "http://marklogic.com/cpf/convert" at "/MarkLogic/conversion/convert.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";
import module namespace t="http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";
import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

declare namespace dir = "http://marklogic.com/xdmp/directory";

declare variable $FS-PATH  as xs:string :=
    if(xdmp:platform() eq "winnt") then "\" else "/";

declare variable $MODULES-DB := xdmp:modules-database();

declare option xdmp:mapping "false";

declare function m:get-tests-from-filesystem(
  $root as xs:string,
  $filter as xs:string)
{
  let $entries := xdmp:filesystem-directory($root)/dir:entry
  return
  (
    for $entry in $entries[dir:type = "directory"]
    return
      m:get-tests-from-filesystem($entry/dir:pathname, $filter),
    for $entry in $entries[dir:type = "file"]
    where fn:ends-with($entry/dir:filename, $filter)
    return
      $entry/dir:pathname
  )
};

declare function m:get-tests-from-modules-with-lexicon(
  $root as xs:string,
  $filter as xs:string)
{
  xdmp:eval('
    declare variable $uri as xs:string external;
    cts:uri-match($uri)',
    (xs:QName('uri'), u:join-file(($root, fn:concat('*', $filter)))),
    <options xmlns="xdmp:eval">
      <database>{$MODULES-DB}</database>
    </options>)
};

declare function m:get-tests-from-modules-sans-lexicon(
  $root as xs:string,
  $filter as xs:string)
{
  let $uris :=
    fn:distinct-values(
      xdmp:eval('
        declare variable $root as xs:string external;
        declare variable $filter as xs:string external;
        xdmp:directory($root, "infinity")/xdmp:node-uri(.)[fn:ends-with(., $filter)]',
        (xs:QName('root'), $root, xs:QName('filter'), $filter),
        <options xmlns="xdmp:eval">
          <database>{$MODULES-DB}</database>
        </options>))
  return
    $uris
};

(:
 : Generates a list of unit tests
:)
declare function m:list()
{
  m:list(u:join-file((xdmp:modules-root(), "test/")), "-test.xqy")
};

(:
 : Generates a list of unit tests
:)
declare function m:list(
  $root as xs:string,
  $filter as xs:string)
{
  element t:tests
  {
    let $db-id as xs:unsignedLong := $MODULES-DB
    let $tests as xs:string* :=
      if ($MODULES-DB = 0) then
        get-tests-from-filesystem($root, $filter)
      else
        if (admin:database-get-uri-lexicon(admin:get-configuration(), $MODULES-DB)) then
          m:get-tests-from-modules-with-lexicon($root, $filter)
        else
          m:get-tests-from-modules-sans-lexicon($root, $filter)
    for $test in $tests
    return
      element t:test
      {
        attribute path { $test },
        element t:assertions
        {
          for $assertion in m:get-test-functions($test)[fn:not(. = ("setup", "teardown"))]
          return
            element t:assertion
            {
              $assertion
            }
        }
      }
  }
};

declare function m:get-test-functions(
  $test-path as xs:string) as xs:string*
{
  let $test :=
    if (xdmp:modules-database() eq 0) then
        xdmp:document-get(
          $test-path,
          <options xmlns="xdmp:document-get">
            <format>text</format>
          </options>)
    else
    xdmp:eval(
      fn:concat('fn:doc("', $test-path, '")'),
      (),
      <options xmlns="xdmp:eval">
        <database>{$MODULES-DB}</database>
      </options>)
  return
    fn:analyze-string($test, "declare\s+function\s+([^(\s]+)")//*:group/fn:tokenize(., ":")[2]
};

declare function m:run-test($test-path as xs:string)
{
  m:run-test($test-path, fn:true())
};

declare function m:run-test(
  $test-path as xs:string,
  $run-teardown as xs:boolean)
{
  m:run-test($test-path, (), $run-teardown)
};

declare function m:run-test(
  $test-path as xs:string,
  $assertions-to-run as xs:string*,
  $run-teardown as xs:boolean)
{
  let $test-name := cvt:basename($test-path)
  let $functions := m:get-test-functions($test-path)
  let $start-time := xdmp:elapsed-time()
  let $results :=
    (
      let $setup := m:run-setup($functions, $test-path)
      return
        if (fn:exists($setup)) then $setup
        else
          m:run-assertions($functions, $assertions-to-run, $test-path),

      if ($run-teardown) then
        m:run-teardown($functions, $test-path)
      else ()
    )
  let $end-time := xdmp:elapsed-time()
  return
    element t:test
    {
      attribute name { $test-name },
      attribute assertions { fn:count($results/self::t:assertion) },
      attribute successes { fn:count($results/self::t:assertion[@type='success'])},
      attribute failures { fn:count($results/self::t:assertion[@type='failure']) },
      attribute errors { fn:count($results/self::t:error) },
      attribute time { functx:total-seconds-from-duration($end-time - $start-time) },
      $results
    }
};

declare function m:run-tests($test-paths as xs:string+)
{
  m:run-tests($test-paths, fn:true())
};

declare function m:run-tests(
  $test-paths as xs:string+,
  $run-teardown as xs:boolean)
{
  let $start-time := xdmp:elapsed-time()
  let $results :=
    for $test-path in $test-paths
    return
      m:run-test($test-path, $run-teardown)
  let $end-time := xdmp:elapsed-time()
  return
    element t:tests
    {
      attribute assertions { fn:sum($results/@assertions) },
      attribute successes { fn:sum($results/@successes) },
      attribute failures { fn:sum($results/@failures) },
      attribute errors { fn:sum($results/@errors) },
      attribute time { functx:total-seconds-from-duration($end-time - $start-time) },
      $results
    }
};

declare private function m:run-setup(
  $functions as xs:string*,
  $test-path as xs:string)
{
  if ($functions[. = "setup"]) then
    try
    {
      m:eval-func('setup', $test-path)
    }
    catch($ex)
    {
      m:handle-error("setup", $ex)
    }
  else ()
};

declare private function m:run-teardown(
  $functions as xs:string*,
  $test-path as xs:string)
{
  if ($functions[. = "teardown"]) then
    try
    {
      m:eval-func('teardown', $test-path)
    }
    catch($ex)
    {
      m:handle-error("teardown", $ex)
    }
  else ()
};

declare private function m:run-assertion(
  $function as xs:string,
  $test-path as xs:string)
{
  try
  {
    for $assertion in m:eval-func($function, $test-path)
    return
      element t:assertion
      {
        attribute name { $function },
        $assertion/@*[fn:not(self::attribute(name))],
        $assertion/node()
      }
  }
  catch($ex)
  {
    m:handle-error($function, $ex)
  }
};

declare private function m:run-assertions(
  $functions as xs:string*,
  $assertions-to-run as xs:string*,
  $test-path as xs:string)
{
  for $f in $functions[fn:not(. = ("setup", "teardown"))]
                      [if ($assertions-to-run) then . = $assertions-to-run else fn:true()]
  return
    m:run-assertion($f, $test-path)
};

declare private function m:eval-func(
  $func-name as xs:string,
  $test-path as xs:string) as element(t:assertion)*
{
  let $test-path :=
    if (xdmp:modules-database() eq 0) then
      fn:replace($test-path, xdmp:modules-root(), "")
    else
      $test-path
  return
  element result
  {
    xdmp:eval(
      fn:concat('
        import module namespace test="http://marklogic.com/roxy/test" at "', $test-path, '";
        test:', $func-name, '()'))
  }/t:assertion
};

declare private function m:test-fail(
  $test-name as xs:string,
  $error as element(error:error))
{
  element t:assertion
  {
    attribute name { $test-name },
    attribute type { "failure" },
    $error
  }
};

declare private function m:test-error(
  $test-name as xs:string,
  $error as element(error:error))
{
  element t:error
  {
    attribute name { $test-name },
    $error
  }
};

declare function m:handle-error(
  $test-name as xs:string,
  $error as element(error:error))
{
  xdmp:log($error),
  if ($error/error:name eq "TEST-FAIL") then
    m:test-fail($test-name, $error)
  else
    m:test-error($test-name, $error)
};