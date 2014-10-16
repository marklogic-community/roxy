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
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare namespace jsonb = "http://marklogic.com/xdmp/json/basic";

declare option xdmp:mapping "false";

(: Execute a search with the configured options :)
declare function m:search($query as xs:string, $startIndex as xs:int, $count as xs:int) {
    search:search($query, $c:SEARCH-OPTIONS, $startIndex, $count)
};

(: Run a cts-query with the configured options :)
declare function m:run-query($cts-query as element(), $startIndex as xs:int, $count as xs:int) {
	search:resolve($cts-query, $c:SEARCH-OPTIONS, $startIndex, $count)
};

declare function m:build-facet-query($facets as xs:string*) {
	let $and-joiner := (($c:SEARCH-OPTIONS, search:get-default-options())/search:grammar/search:joiner[@element/fn:string()="cts:and-query"]/fn:string())[1]
	let $facet-string := fn:string-join($facets, " " || $and-joiner || " ")
	return cts:query(search:parse($facet-string, $c:SEARCH-OPTIONS))
};

declare function m:build-datetime-query($startDate as xs:dateTime*, $endDate as xs:dateTime*) {
	<x>
	{
		cts:and-query((
			if (fn:empty($startDate)) then () else cts:element-range-query($c:DATE-RANGE-ELEMENT-NAMES, ">", $startDate),
			if (fn:empty($endDate)) then () else cts:element-range-query($c:DATE-RANGE-ELEMENT-NAMES, "<=", $endDate)
		))
	}
	</x>/node()
};

(: Parse a search string and apply the configured search options :)
declare function m:parse($query as xs:string) {
	search:parse($query, $c:SEARCH-OPTIONS)
};

declare function m:format-results($response) {
	let $execTimestamp := fn:current-dateTime()

	(: Build the main search response object :)
	let $xml := 
		<json type="object" xmlns="http://marklogic.com/xdmp/json/basic">
			<execTimestamp type="string">{$execTimestamp}</execTimestamp>
			<startIndex type="number">{ $response/@start/fn:string() }</startIndex>
			<count type="number">{ $response/@page-length/fn:string() }</count>
			<total type="number">{$response/@total/fn:string()}</total>
			<results type="array">
			{	
				for $result in $response/search:result
				return m:format-result($result)
			}
			</results>
			{ m:format-facets($response/search:facet) }
		</json>
	return
		json:transform-to-json($xml)
};

declare function m:format-result($result) {
	let $uri := $result/@uri/fn:string()
	let $doc := fn:doc($uri)
	let $xml := 
		<json type="object" xmlns="http://marklogic.com/xdmp/json/basic">
			<index type="string">{$result/@index/fn:string()}</index>
			<uri type="string">{$uri}</uri>
			<title type="string">{ xdmp:unpath('fn:doc("' || $uri || '")' || $c:TITLE-PATH) }</title>
			{m:snippet($result)}
			<score type="string">{$result/@score/fn:string()}</score>
			<fitness type="string">{$result/@fitness/fn:string()}</fitness>
			<confidence type="string">{$result/@confidence/fn:string()}</confidence>
		</json>
	return
		$xml
};

declare function m:format-facets($facets) {
	<facets type="object" xmlns="http://marklogic.com/xdmp/json/basic">
	{	
		for $g in $c:FACET-GROUPS/c:group
		return
			element { $g/@name } {
				attribute type { "object" },
				for $facet in $facets//search:facet-value/..[@name = $g/c:facet-name]
				return
					element {$facet/@name} {
						attribute {"type"} {"array"},
						for $fv in $facet/search:facet-value
						return
							<json type="object">
							{	
								for $attr in $fv/@*
								return
									element { $attr/fn:name() } { 
										attribute {"type"} { "string" },
										$attr/fn:string()
									}
							}
							</json>
					}
			}
	}
	</facets>
};

declare function m:snippet($result) {
	<jsonb:snippets type="array">{m:snippet-transform($result)}</jsonb:snippets>
};

declare function m:snippet-passthrough($x as node()) as node()* {
	for $z in $x/node() return m:snippet-transform($z)
};

declare function m:snippet-transform($x as node()) as node()* {
	typeswitch($x)
		case text() return $x
		case element (search:highlight) return <span class='snippet-term-highlight'>{$x/fn:string()}</span>
		case element (search:match) return 
			<jsonb:item type="string">
				{xdmp:quote(<span class='snippet'>{m:snippet-passthrough($x)}</span>)}
			</jsonb:item>
		default return m:snippet-passthrough($x)
};