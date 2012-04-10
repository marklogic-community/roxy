(:
Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
xquery version "1.0-ml";

module namespace m = "http://marklogic.com/roxy/models/search";

import module namespace c = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";

import module namespace debug = "http://marklogic.com/debug" at "/MarkLogic/appservices/utils/debug.xqy";
import module namespace search="http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";
import module namespace impl = "http://marklogic.com/appservices/search-impl" at "/MarkLogic/appservices/search/search-impl.xqy";

declare option xdmp:mapping "false";

declare function m:search($query as xs:string, $page as xs:int)
{
  let $start := ($page - 1) * $c:DEFAULT-PAGE-LENGTH + 1
  return
    search:search($query, $c:SEARCH-OPTIONS, $start, $c:DEFAULT-PAGE-LENGTH)
};
declare function m:facets-only($query, $options) as element(search:facet)*
{
  let $init-options := impl:merge-options($impl:default-options, $options)
  let $parsed-query := 
    if ($init-options) then
      impl:do-tokenize-parse($query, $init-options, fn:false())
    else
      fn:error((),"SEARCH-INVALARGS",("requires either $ctsquery or $qtext and $options"))
  (: create and merge final options with any state contained in the parsed query :)
  let $options := impl:apply-state($init-options,$parsed-query)

  let $combined-query :=
    let $extra-cts := $options/search:additional-query/*
    return
      if ($parsed-query and $extra-cts) then
        element cts:and-query { ($parsed-query, $extra-cts) }
      else
        $parsed-query
  return
    impl:do-resolve-facets($options, $combined-query, 100)
};