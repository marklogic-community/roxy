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

module namespace c = "http://marklogic.com/roxy/controller/main";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

import module namespace s = "http://marklogic.com/roxy/models/search" at "/app/models/search-lib.xqy";
import module namespace geo = "http://marklogic.com/roxy/models/geo" at "/app/models/geo-lib.xqy";
import module namespace ts = "http://marklogic.com/roxy/models/timeseries" at "/app/models/timeseries-lib.xqy";
import module namespace conf = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";

import module namespace search="http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
declare option xdmp:mapping "false";

(:
 : Usage Notes:
 :
 : use the ch library to pass variables to the view
 :
 : use the request (req) library to get access to request parameters easily
 :
 :)
declare function c:main() as item()*
{
  ch:add-value("SEARCH-NOT-OPERATOR", (($conf:SEARCH-OPTIONS, search:get-default-options())/search:grammar/search:starter[@element/fn:string()="cts:not-query"]/fn:string())[1]),
  ch:add-value("PAGELENGTH", $conf:DEFAULT-PAGE-LENGTH),
  ch:add-value("GEO-ENABLED", $conf:GEO-ENABLED),
  ch:add-value("GOOGLEMAPS-API-KEY", $conf:GOOGLEMAPS-API-KEY),
  ch:add-value("DATE-RANGE-ENABLED", $conf:DATE-RANGE-ENABLED),
  ch:add-value("TIMESERIES-ENABLED", $conf:TIMESERIES-ENABLED),
  ch:use-layout(())
};

declare function c:search() as item()* {
  let $startIndex as xs:int := req:get("startIndex", 1, "type=xs:int")
  let $count := req:get("count", $conf:DEFAULT-PAGE-LENGTH, "type=xs:int")
  let $language := fn:substring(xdmp:get-request-header("Accept-Language", "en-US,en;q=0.8"), 1, 2)

  let $query := c:build-query()

  let $_ := xdmp:log(xdmp:quote($query))
    
  let $results := s:run-query($query, $startIndex, $count)
  return s:format-results($results, $language)
};

declare function c:renderDocument() as item()* {
  let $uri := req:required("uri", "type=xs:string")
  let $doc := if ($uri != "" and xdmp:exists(fn:doc($uri))) then fn:doc($uri) else "No document found for URI " || $uri
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <pre>{xdmp:quote($doc)}</pre>
      </body>
    </html>
};

declare private function c:build-query() {
  let $q as xs:string := req:get("q", "", "type=xs:string")
  let $facets as xs:string* := fn:tokenize(req:get("facets", (), "type=xs:string"), "_FACET_")
  let $geo-json as xs:string* := req:get("geoBoundaries", (), "type=xs:string")
  let $start-date := req:get("startDate", (), "type=xs:dateTime")
  let $end-date := req:get("endDate", (), "type=xs:dateTime")
  return
    <cts:and-query>
    {
      s:parse($q),
      s:build-facet-query($facets),
      if (fn:not($conf:DATE-RANGE-ENABLED)) then () else s:build-datetime-query($start-date, $end-date),
      if (fn:empty($geo-json) or fn:not($conf:GEO-ENABLED)) then () else geo:build-geo-query($geo-json)
    }
    </cts:and-query>
};

(: Gets the time-series data for a query :)
declare function c:getTimeseriesData() as item()* {
    let $date-string := req:get("dateString", (), "type=xs:string")

    let $query := c:build-query()

    let $data-map := ts:build-timeseries-map($query, $date-string)

    let $responseMap := map:map()
    let $_ := map:put($responseMap, "success", fn:true())
    let $_ := map:put($responseMap, "data", $data-map)
    let $m := map:map()
    let $_ := map:put($m, "response", $responseMap)
    return xdmp:to-json($m)
};

declare function c:getGeoData() as item()* {
    let $query := c:build-query()

    let $points := if (fn:not($conf:GEO-ENABLED)) then () else geo:get-geo-points($query)

    let $xml :=
        <json type="object" xmlns="http://marklogic.com/xdmp/json/basic">
            <response type="object">
                <data type="object">
                    <points type="array">
                    {
                        for $point in $points
                        return
                            <point type="array">
                                <latitude type="number">{cts:point-latitude($point)}</latitude>
                                <longitude type="number">{cts:point-longitude($point)}</longitude>
                            </point>
                    }
                    </points>
                </data>
                <success type="boolean">true</success>
            </response>
        </json>

    return json:transform-to-json($xml)
};