(:
Copyright 2012-2015 MarkLogic Corporation

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

declare function pager:paginate(
  $response as element(search:response))
{
  pager:paginate($response, 0)
};

declare function pager:paginate(
  $response as element(search:response),
  $visible-links as xs:int)
{
  pager:paginate(
    $response/@start,
    $response/@page-length,
    $response/@total,
    $visible-links)
};

declare function pager:paginate(
  $start as xs:int,
  $page-length as xs:int,
  $total as xs:int,
  $visible-links as xs:int)
{
  let $page := ($start - 1) div $page-length + 1
  let $total-pages := fn:ceiling($total div $page-length)
  let $links-to-show := fn:min(($visible-links, $total-pages)) - 1
  let $start-item as xs:int := $start
  let $total-items as xs:int := $total
  let $per-page as xs:int := $page-length
  let $start-link :=
    if ($page >= 3 and $page <= $total-pages - 2) then $page - 2
    else if ($page < 3 and $page + $links-to-show <= $total-pages) then $page
    else if ($page > $total-pages - 2) then $total-pages - $links-to-show
    else 1
  let $last-link := $start-link + $links-to-show
  return
    <pagination xmlns="http://marklogic.com/roxy/pager-lib">
      <current-page>{$page}</current-page>
      <total-pages>{$total-pages}</total-pages>
      <page-length>{$per-page}</page-length>
      <previous-index>{if ($page > 1) then $start-item - $per-page else ()}</previous-index>
      <previous-page>{if ($page > 1) then $page - 1 else ()}</previous-page>
      <next-index>{if ($page < $total-pages) then $start-item + $per-page else ()}</next-index>
      <next-page>{if ($page < $total-pages) then $page + 1 else ()}</next-page>
      <showing>
        <start>{$start-item}</start>
        <end>{fn:string(fn:min(($start + $page-length - 1, $total)))}</end>
        <total>{$total-items}</total>
      </showing>
      {
        if ($visible-links > 0) then
          <links>
          {
            for $i in ($start-link to $last-link)
            return
              <link>{$i}</link>
          }
          </links>
        else ()
      }
    </pagination>
};

declare function pager:pagination(
  $response as element(search:response),
  $base-uri as xs:string,
  $index-param as xs:string)
{
  let $pagination := pager:paginate($response)
  return
  (
    if (fn:exists($pagination/pager:previous-index/text())) then
      let $href := pager:build-href($base-uri, $index-param, $pagination/pager:previous-index)
      return
        <span class="previous" xmlns="http://www.w3.org/1999/xhtml"><a href="{$href}">&laquo;</a></span>
    else (),
    <span class="page-numbers" xmlns="http://www.w3.org/1999/xhtml">Results <b>{fn:data($pagination/pager:showing/pager:start)}</b> to <b>{fn:data($pagination/pager:showing/pager:end)}</b> of <b>{fn:data($pagination/pager:showing/pager:total)}</b></span>,
    if (fn:exists($pagination/pager:next-index/text())) then
      let $href := pager:build-href($base-uri, $index-param, $pagination/pager:next-index)
      return
        <span class="next" xmlns="http://www.w3.org/1999/xhtml"><a href="{$href}">&raquo;</a></span>
    else ()
  )
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
