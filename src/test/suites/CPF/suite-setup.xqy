xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

if (xdmp:modules-database() eq 0) then
  test:fail("You must run this test from a modules database.")
else ();

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";

if (xdmp:triggers-database() ne 0) then
  cpf:clean-cpf()
else ()
