xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";

if (xdmp:triggers-database() ne 0) then
  cpf:clean-cpf()
else ()