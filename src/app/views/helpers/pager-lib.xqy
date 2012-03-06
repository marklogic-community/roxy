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

(: Generates a set of links for paging.
 : To use this library:
 : call pager:pagination()
 : parameters --
 :   $response - the search:response element (needed) :)

module namespace pager = "http://marklogic.com/roxy/pager-lib";

declare namespace search = "http://marklogic.com/appservices/search";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare function pager:pagination(
  $start as xs:int,
  $page-length as xs:int,
  $total as xs:int,
  $base-uri as xs:string,
  $index-param as xs:string)
{
  pager:previous-page($start, $page-length, $total, $base-uri, $index-param),
  pager:show-page-numbers($start, $page-length, $total),
  pager:next-page($start, $page-length, $total, $base-uri, $index-param)
};

declare function pager:pagination(
  $response as element(search:response),
  $base-uri as xs:string,
  $index-param as xs:string)
{
  pager:pagination($response/@start, $response/@page-length, $response/@total, $base-uri, $index-param)
};

declare function pager:previous-page(
  $start as xs:int,
  $page-length as xs:int,
  $total as xs:int,
  $base-uri as xs:string,
  $index-param as xs:string)
{
  if ($start gt 1) then
    let $href := pager:build-href($base-uri, $index-param, $start - $page-length)
    return
      <span class="previous">
          <a href="{$href}">&laquo;</a>
      </span>
  else ()
};

declare function pager:show-page-numbers(
  $start as xs:int,
  $page-length as xs:int,
  $total as xs:int)
{
  <span class="page-numbers">Results <b>{fn:string($start)}</b> to <b>{fn:min(($start + $page-length - 1, fn:data($total)))}</b> of <b>{fn:string($total)}</b>
  </span>
};

declare function pager:next-page(
  $start as xs:int,
  $page-length as xs:int,
  $total as xs:int,
  $base-uri as xs:string,
  $index-param as xs:string)
{
  if (($start + $page-length) lt $total) then
    let $href := pager:build-href($base-uri, $index-param, $start + $page-length)
    return
      <span class="next">
        <a href="{$href}">&raquo;</a>
      </span>
  else ()
};

declare private function pager:build-href($base-uri, $index-param, $index-value)
{
  if (fn:matches($base-uri, $index-param)) then
    fn:replace(
      $base-uri,
      fn:concat("(", $index-param, "=\d*)"),
      fn:concat($index-param, "=", $index-value))
  else
    let $joiner := if (fn:matches($base-uri, "\?")) then "&amp;" else "?"
    return fn:concat($base-uri, $joiner, $index-param, "=", $index-value)
};
