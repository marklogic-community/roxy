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

module namespace m = "http://marklogic.com/roxy/models/timeseries";

import module namespace conf = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare function m:build-timeseries-map($ml-query, $value) as map:map {
	let $ml-query := cts:query($ml-query)
	let $scope :=
		if (fn:empty($value) or $value = '') then 'yearly'
		else if (fn:not(fn:contains($value, "/"))) then 'monthly'
		else if (fn:count(fn:tokenize($value, "/")) = 2) then 'daily'
		else 'hourly'
	let $now := fn:current-dateTime()
	let $timezone := if (fn:contains(fn:string($now), "Z")) then "Z" else "-" || fn:tokenize(fn:string($now), '-')[fn:last()]

	let $data-map := map:map()
	let $_ :=
		if ($scope = 'yearly') then
			let $year-start := xs:dateTime(functx:first-day-of-year($now) || 'T00:00:00.000000' || $timezone)
			let $year-end := xs:dateTime(functx:last-day-of-year($now) || 'T23:59:59.999999' || $timezone)
			let $end := $year-end
			let $start := $year-start
			for $i in (1 to $conf:TIMESERIES-DISPLAY-YEARS)
			let $query := cts:and-query((
				$ml-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $last-year := xs:date($start - xs:dayTimeDuration('P365D'))
			let $_ := map:put($data-map, fn:tokenize(fn:string($start), '-')[1], xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, xs:dateTime(functx:first-day-of-year($last-year) || 'T00:00:00.000000' || $timezone)), xdmp:set($end, xs:dateTime(functx:last-day-of-year($last-year) || 'T23:59:59.999999' || $timezone)))
		else if ($scope = 'monthly') then
			let $year := xs:dateTime($value || '-01-01T00:00:00.000000' || $timezone)
			let $month-start := $year
			let $month-end := xs:dateTime(functx:last-day-of-month($year) || 'T23:59:59.999999' || $timezone)
			let $end := $month-end
			let $start := $month-start
			for $i in (1 to 12)
			let $query := cts:and-query((
				$ml-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $next-month := xs:date(functx:next-day($end))
			let $_ := map:put($data-map, functx:month-name-en($end), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, xs:dateTime(functx:first-day-of-month($next-month) || 'T00:00:00.000000' || $timezone)), xdmp:set($end, xs:dateTime(functx:last-day-of-month($next-month) || 'T23:59:59.999999' || $timezone)))
		else if ($scope = 'daily') then
			let $year := fn:tokenize($value, "/")[1]
			let $month := fn:index-of(("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"), fn:tokenize($value, "/")[2])
			let $day-start := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-01T00:00:00.000000" || $timezone)
			let $day-end := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-01T23:59:59.999999" || $timezone)
			let $end := $day-end
			let $start := $day-start
			for $i in (1 to functx:days-in-month($start))
			let $query := cts:and-query((
				$ml-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $_ := map:put($data-map, fn:substring(fn:substring-before(fn:string($start), 'T'), 9, 2), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, $start + xs:dayTimeDuration('P1D')), xdmp:set($end, $end + xs:dayTimeDuration('P1D')))
		else
			let $year := fn:tokenize($value, "/")[1]
			let $month := fn:index-of(("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"), fn:tokenize($value, "/")[2])
			let $day := fn:tokenize($value, "/")[3]
			let $hour-start := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-" || $day || "T00:00:00.000000" || $timezone)
			let $hour-end := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-" || $day || "T01:00:00.000000" || $timezone)
			let $end := $hour-end
			let $start := $hour-start
			for $i in (1 to 24)
			let $query := cts:and-query((
				$ml-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $_ := map:put($data-map, fn:substring(fn:substring-after(fn:string($start), 'T'), 1, 5), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, $start + xs:dayTimeDuration('PT1H')), xdmp:set($end, $end + xs:dayTimeDuration('PT1H')))
	return $data-map
};