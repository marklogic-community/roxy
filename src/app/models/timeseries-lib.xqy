(:
Copyright 2014 MarkLogic Corporation

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

(:
 : ***********************************************
 : Builds a map of time-bucketed document counts. The results are constrained by
 : the input query. The date-string represents the time range of interest
 : (e.g. 2014/January/08, 2012/March, or simply 2013).
 : If no date-string is provided, the results are document counts per year.
 : If the date-string is a year value, the monthly counts for that year are returned.
 : If the date-string is a year/month value, the daily counts for that month are returned.
 : If the date-string is a year/month/day value, the hourly counts for that day are returned.
 : @param cts-query The query to apply to the counts
 : @param date-string The string representation of the time range of interest.
 :   Format is YYYY/Month/DD
 : @output A map of the document counts for the current view
 :   e.g.
 :   $date-string = () or ''
 :     {"2008": 235, "2009": 352, "2010": 680, "2011": 703, "2012": 199, "2013": 806, "2014": 744}
 :   $date-string = "2010"
 :     {"January": 102, "February": 369, "March": 426, ...}
 : ***********************************************
:)
declare function m:build-timeseries-map($cts-query as element(), $date-string as xs:string*) as map:map {
	let $cts-query := cts:query($cts-query)
	let $scope :=
		if (fn:empty($date-string) or $date-string = '') then 'yearly'
		else if (fn:not(fn:contains($date-string, "/"))) then 'monthly'
		else if (fn:count(fn:tokenize($date-string, "/")) = 2) then 'daily'
		else 'hourly'
	let $now := fn:current-dateTime()
	let $timezone := if (fn:contains(fn:string($now), "Z")) then "Z" else "-" || fn:tokenize(fn:string($now), '-')[fn:last()]
	let $months-sequence := ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")

	let $data-map := map:map()
	let $_ :=
		if ($scope = 'yearly') then
			let $year-start := xs:dateTime(functx:first-day-of-year($now) || 'T00:00:00.000000' || $timezone)
			let $year-end := xs:dateTime(functx:last-day-of-year($now) || 'T23:59:59.999999' || $timezone)
			let $end := $year-end
			let $start := $year-start
			for $i in (1 to $conf:TIMESERIES-DISPLAY-YEARS)
			let $query := cts:and-query((
				$cts-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $last-year := xs:date($start - xs:dayTimeDuration('P365D'))
			let $_ := map:put($data-map, fn:tokenize(fn:string($start), '-')[1], xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, xs:dateTime(functx:first-day-of-year($last-year) || 'T00:00:00.000000' || $timezone)), xdmp:set($end, xs:dateTime(functx:last-day-of-year($last-year) || 'T23:59:59.999999' || $timezone)))
		else if ($scope = 'monthly') then
			let $year := xs:dateTime($date-string || '-01-01T00:00:00.000000' || $timezone)
			let $month-start := $year
			let $month-end := xs:dateTime(functx:last-day-of-month($year) || 'T23:59:59.999999' || $timezone)
			let $end := $month-end
			let $start := $month-start
			for $i in (1 to 12)
			let $query := cts:and-query((
				$cts-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $next-month := xs:date(functx:next-day($end))
			let $_ := map:put($data-map, functx:month-name-en($end), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, xs:dateTime(functx:first-day-of-month($next-month) || 'T00:00:00.000000' || $timezone)), xdmp:set($end, xs:dateTime(functx:last-day-of-month($next-month) || 'T23:59:59.999999' || $timezone)))
		else if ($scope = 'daily') then
			let $year := fn:tokenize($date-string, "/")[1]
			let $month := fn:index-of($months-sequence, fn:tokenize($date-string, "/")[2])
			let $day-start := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-01T00:00:00.000000" || $timezone)
			let $day-end := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-01T23:59:59.999999" || $timezone)
			let $end := $day-end
			let $start := $day-start
			for $i in (1 to functx:days-in-month($start))
			let $query := cts:and-query((
				$cts-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $_ := map:put($data-map, fn:substring(fn:substring-before(fn:string($start), 'T'), 9, 2), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, $start + xs:dayTimeDuration('P1D')), xdmp:set($end, $end + xs:dayTimeDuration('P1D')))
		else
			let $year := fn:tokenize($date-string, "/")[1]
			let $month := fn:index-of($months-sequence, fn:tokenize($date-string, "/")[2])
			let $day := fn:tokenize($date-string, "/")[3]
			let $hour-start := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-" || $day || "T00:00:00.000000" || $timezone)
			let $hour-end := xs:dateTime($year || "-" || functx:pad-integer-to-length($month, 2) || "-" || $day || "T01:00:00.000000" || $timezone)
			let $end := $hour-end
			let $start := $hour-start
			for $i in (1 to 24)
			let $query := cts:and-query((
				$cts-query,
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '>=', $start),
				cts:element-range-query($conf:DATE-RANGE-ELEMENT-NAMES, '<', $end)
			))
			let $_ := map:put($data-map, fn:substring(fn:substring-after(fn:string($start), 'T'), 1, 5), xdmp:estimate(cts:search(/, $query)))
			return (xdmp:set($start, $start + xs:dayTimeDuration('PT1H')), xdmp:set($end, $end + xs:dayTimeDuration('PT1H')))
	return $data-map
};