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

module namespace m = "http://marklogic.com/roxy/models/geo";

import module namespace c = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

(: Get all the points contained in fragments that match a query :)
declare function m:get-geo-points($ml-query) {
	let $ml-query := cts:query($ml-query)
	let $points :=
		try {
			if (fn:empty($c:GEO-ELEMENT-INDEX-NAMES)) then
				()
			else
				cts:element-geospatial-values(
					$c:GEO-ELEMENT-INDEX-NAMES,
					(),
					("limit=" || $c:GEO-VALUES-LIMIT),
					$ml-query
				)
		} catch ($e) {
			()
		}
	let $points2 :=
		try {
			if (fn:empty($c:GEO-ELEMENT-CHILD-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ELEMENT-CHILD-INDEX-NAMES)) then
				()
			else
				cts:element-child-geospatial-values(
					$c:GEO-ELEMENT-CHILD-INDEX-PARENT-NAMES,
					$c:GEO-ELEMENT-CHILD-INDEX-NAMES,
					(),
					("limit=" || $c:GEO-VALUES-LIMIT),
					$ml-query
				)
		} catch ($e) {
			()
		}
	let $points3 :=
		try {
			if (fn:empty($c:GEO-ELEMENT-PAIR-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ELEMENT-PAIR-INDEX-LAT-NAMES) or fn:empty($c:GEO-ELEMENT-PAIR-INDEX-LON-NAMES)) then
				()
			else
				cts:element-pair-geospatial-values(
					$c:GEO-ELEMENT-PAIR-INDEX-PARENT-NAMES,
					$c:GEO-ELEMENT-PAIR-INDEX-LAT-NAMES,
					$c:GEO-ELEMENT-PAIR-INDEX-LON-NAMES,
					(),
					("limit=" || $c:GEO-VALUES-LIMIT),
					$ml-query
				)
		} catch ($e) {
			()
		}
	let $points4 :=
		try {
			if (fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-LAT-NAMES) or fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-LON-NAMES)) then
				()
			else
				cts:element-attribute-pair-geospatial-values(
					$c:GEO-ATTRIBUTE-PAIR-INDEX-PARENT-NAMES,
					$c:GEO-ATTRIBUTE-PAIR-INDEX-LAT-NAMES,
					$c:GEO-ATTRIBUTE-PAIR-INDEX-LON-NAMES,
					(),
					("limit=" || $c:GEO-VALUES-LIMIT),
					$ml-query
				)
		} catch ($e) {
			()
		}
	let $points5 :=
		try {
			if (fn:empty($c:GEO-PATH-INDEX-PATHS)) then
				()
			else
				cts:values(
					(for $path in $c:GEO-PATH-INDEX-PATHS return cts:path-reference($path)),
					(),
					("limit=" || $c:GEO-VALUES-LIMIT),
					$ml-query
				)
		} catch ($e) {
			()
		}
	
	return ($points, $points2, $points3, $points4, $points5)
};

declare function m:build-geo-query($geo-json as xs:string) {
	let $xml := if ($geo-json) then json:transform-from-json($geo-json) else ()
	let $circles := $xml/*:circles/*:json
	let $rectangles := $xml/*:rectangles/*:json/*:bounds
	let $polygons := $xml/*:polygons/*:json/*:paths/*:json
	let $cts-circles :=
		for $circle in $circles
		return cts:circle(
				xs:float($circle/*:radius) * .000621371,
				cts:point(xs:float(($circle/*:center/*:item)[1]), xs:float(($circle/*:center/*:item)[2]))
			)
	let $cts-rectangles :=
		for $rectangle in $rectangles
		return cts:box(
				xs:float(($rectangle/*:item)[1]),
				xs:float(($rectangle/*:item)[2]),
				xs:float(($rectangle/*:item)[3]),
				xs:float(($rectangle/*:item)[4])
			)
	let $cts-polygons :=
		for $polygon in $polygons
		let $path := $polygon/*:path
		return cts:polygon(
				let $points :=
					for $point in $path/*:json
					return cts:point(($point/*:item)[1], ($point/*:item)[2])
				return ($points, $points[1])
			)
	let $regions := ($cts-circles, $cts-rectangles, $cts-polygons)
	let $query :=
		if (fn:exists($regions)) then
				<cts:or-query>
				{
					if (fn:empty($c:GEO-ELEMENT-INDEX-NAMES)) then
						()
					else
						cts:element-geospatial-query($c:GEO-ELEMENT-INDEX-NAMES, $regions),
					if (fn:empty($c:GEO-ELEMENT-CHILD-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ELEMENT-CHILD-INDEX-NAMES)) then
						()
					else
						cts:element-child-geospatial-query(
							$c:GEO-ELEMENT-CHILD-INDEX-PARENT-NAMES,
							$c:GEO-ELEMENT-CHILD-INDEX-NAMES,
							$regions
						),
					if (fn:empty($c:GEO-ELEMENT-PAIR-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ELEMENT-PAIR-INDEX-LAT-NAMES) or fn:empty($c:GEO-ELEMENT-PAIR-INDEX-LON-NAMES)) then
						()
					else
						cts:element-pair-geospatial-query(
							$c:GEO-ELEMENT-PAIR-INDEX-PARENT-NAMES,
							$c:GEO-ELEMENT-PAIR-INDEX-LAT-NAMES,
							$c:GEO-ELEMENT-PAIR-INDEX-LON-NAMES,
							$regions
						),
					if (fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-PARENT-NAMES) or fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-LAT-NAMES) or fn:empty($c:GEO-ATTRIBUTE-PAIR-INDEX-LON-NAMES)) then
						()
					else
						cts:element-attribute-pair-geospatial-query(
							$c:GEO-ATTRIBUTE-PAIR-INDEX-PARENT-NAMES,
							$c:GEO-ATTRIBUTE-PAIR-INDEX-LAT-NAMES,
							$c:GEO-ATTRIBUTE-PAIR-INDEX-LON-NAMES,
							$regions
						),
					if (fn:empty($c:GEO-PATH-INDEX-PATHS)) then
						()
					else
						cts:path-geospatial-query(
							$c:GEO-PATH-INDEX-PATHS,
							$regions
						)
				}
				</cts:or-query>
		else
			<cts:and-query/>
	return $query
};