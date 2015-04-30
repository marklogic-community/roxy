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

module namespace facet = "http://marklogic.com/roxy/facet-lib";

import module namespace search = "http://marklogic.com/appservices/search"
   at "/MarkLogic/appservices/search/search.xqy";

import module namespace trans = "http://marklogic.com/translate"
    at "/MarkLogic/appservices/utils/translate.xqy";

declare namespace lbl = "http://marklogic.com/xqutils/labels";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare variable $FACET-LIMIT := 10;

declare option xdmp:mapping "false";

declare function facet:facets(
  $facets as element(search:facet)*,
  $qtext as xs:string?,
  $options as element(search:options),
  $labels as element(lbl:labels)) as element(div)+
{
  let $controls := map:map()
  let $display :=
    for $facet at $index in $facets
    let $facet-name := fn:data($facet/@name)
    let $facet-count := fn:count($facet/search:facet-value)
    let $match := fn:matches(fn:lower-case($qtext), fn:concat("(^|[ \(])",fn:lower-case($facet-name)))
    return
      <div class="category {fn:concat("category-",$index)} { if ($match) then "selected-category" else ()}">
        <h4 title="Collapse {trans:translate($facet-name, $labels, (), "en")} category">
        { trans:translate($facet-name, $labels, (), "en")}
        </h4>
        <ul>
        {
          let $list-items :=
            for $result in $facet/search:facet-value
            let $facet-val :=
              (: This is not robust because the user can change the grammar. :)
              if (fn:matches($result, "[^\w\d\.]")) then
                fn:concat('"', $result, '"')
              else if ($result eq "") then """"
              else $result/fn:string()
            let $fq := fn:concat($facet-name, ":", $facet-val)
            let $newquery :=
              if ($qtext) then
                if ($match) then
                  search:remove-constraint($qtext, $fq, $options)
                else fn:concat("(", $qtext, ")", " AND ", $fq)
              else $fq
            let $href := fn:concat("/?q=",fn:encode-for-uri($newquery))
            let $title := (trans:translate($result/@name, $labels, (), "en"), $result/fn:string())[1]
            return
              <li>
                <a href="{$href}">{if ($title eq "") then <em>(empty)</em> else $title}</a><i> ({$result/@count/fn:string()})</i>
              </li>
          return (
            ($list-items)[1 to $FACET-LIMIT],
            if ($facet-count > $FACET-LIMIT) then (
              <ul id="all_{$facet-name}">
                {($list-items)[fn:position() gt $FACET-LIMIT]}
              </ul>,
              <li id="view_toggle_{$facet-name}" class="list-toggle">...More</li>
            )
            else (),
            if ($match) then
              map:put(
                $controls,
                $facet-name,
                facet:facet-chiclet($qtext, $options, fn:concat($facet-name,":"), $labels))
            else ()
          )
        }
        </ul>
      </div>
    let $selected := $display[fn:data(@class) = "selected-category"]
    let $header :=
      <div class="sidebar-header" arcsize="5 0 0 0">
      {
        if ($selected) then "You are looking at"
        else "Browse"
      }
      </div>
  let $controls :=
    for $control in map:keys($controls)
    return map:get($controls,$control)

  return ($header,$controls,$display)
};

declare function facet:facet-chiclet(
  $qtext as xs:string,
  $options as element(search:options),
  $facet-name as xs:string,
  $labels as element(lbl:labels))
as element(div)?
{
  let $parsed := search:parse($qtext,$options)
  let $query := facet:extract($parsed, $facet-name)
  return
    if ($query and fn:count($query) eq 1) then
      let $quot := fn:string($options/search:grammar/search:quotation)
      let $quot-len := fn:string-length($quot)
      let $text := search:unparse($query)
      let $newquery := search:remove-constraint($qtext,$text,$options)
      let $href := fn:concat("/?q=",fn:encode-for-uri($newquery))
      let $facet-id := fn:substring-before($facet-name, ":")
      let $facet-val := fn:substring-after($text, $facet-name)
      let $facet-val :=
        if (fn:starts-with($facet-val, $quot)) then
          fn:substring($facet-val, $quot-len + 1)
        else
          $facet-val
      let $facet-val :=
        if (fn:ends-with($facet-val, $quot)) then
          fn:substring($facet-val, 1, fn:string-length($facet-val) - $quot-len)
        else
          $facet-val
      let $bucket-label := $options/search:constraint[@name eq $facet-id]/search:range/search:bucket[@name eq $facet-val]
      let $title :=
        fn:concat(
          trans:translate($facet-id, $labels, (), "en"),
          ":",
          if ($bucket-label) then
            fn:string($bucket-label)
          else
            trans:translate($facet-val, $labels, (), "en")
        )
      return facet:chiclet($href, $title)
    else if ($query and fn:count($query) gt 1) then
      let $q := $qtext
      let $newquery :=
        for $i in $query
        return xdmp:set($q, search:remove-constraint($q, search:unparse($i), $options))
      let $href := fn:concat("/?q=", fn:encode-for-uri($q))
      let $title := trans:translate(fn:substring-before($facet-name, ":"), $labels, (), "en")
      return facet:chiclet($href, $title)
    else ()
};

declare function facet:extract(
  $parsed as element(),
  $facet-name as xs:string)
as schema-element(cts:query)*
{
  if ($parsed/self::cts:properties-query
    or $parsed/self::cts:element-query
    or $parsed/self::cts:element-attribute-pair-geospatial-query
    or $parsed/self::cts:element-child-geospatial-query
    or $parsed/self::cts:element-geospatial-query
    or $parsed/self::cts:element-pair-geospatial-query) then
    () (: Oh, forget it, we don't care about these. Property, element, and geo queries should never produce facets. :)
  else
    if ($parsed[@qtextpre eq $facet-name or fn:contains(@qtextconst,$facet-name)]) then
      $parsed
    else
      for $child in $parsed/*
      return facet:extract($child, $facet-name)
};

declare function facet:chiclet(
  $href as xs:string,
  $title as xs:string)
{
  <div class="facet" title="Remove {$title}">
    <a href="{$href}" class="close">
      <span>&nbsp;</span>
    </a>
    <div class="label" title="{$title}">{$title}</div>
  </div>
};
