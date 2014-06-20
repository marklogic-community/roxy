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

module namespace router = "http://marklogic.com/roxy/router";

import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";
import module namespace config = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";
import module namespace def = "http://marklogic.com/roxy/defaults" at "/roxy/config/defaults.xqy";
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";
import module namespace rh = "http://marklogic.com/roxy/routing-helper" at "/roxy/lib/routing-helper.xqy";
import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

declare option xdmp:mapping "false";

declare variable $controller as xs:QName := req:get("controller", "type=xs:QName");
declare variable $controller-path as xs:string := fn:concat("/app/controllers/", $controller, ".xqy");
declare variable $func as xs:string := req:get("func", "main", "type=xs:string");
declare variable $default-format :=
  (
    $config:ROXY-OPTIONS/*:default-format,
    $def:ROXY-OPTIONS/*:default-format
  )[1];
declare variable $format as xs:string := req:get("format", $default-format, "type=xs:string");
declare variable $default-view as xs:string := fn:concat($controller, "/", $func);

(: assume no default layout for xml, json, text :)
declare variable $default-layout as xs:string? :=
  (
    $config:ROXY-OPTIONS/*:layouts/*:layout[@format = $format],
    $def:ROXY-OPTIONS/*:layouts/*:layout[@format = $format]
  )[1];

(:
  Check for the profiling header.  By default, profiling is not enabled.
:)
declare variable $debug-header as xs:string? := xdmp:get-request-header("X-ML-Profile", "no");

(:
  Start profiling the request, if the profiling header is set to yes.
:)
declare function router:start-profiling() {
  let $request-id := xdmp:request()
  return 
    if ($debug-header = "yes") 
      then
        (xdmp:log("Staring profiling: "||$debug-header), prof:enable($request-id), $request-id)
      else 
        $request-id
};

(:
  Finish porfiling, generating and returning the report.
:)
declare function router:end-profiling($request-id) {
  if ($debug-header = "yes")
    then
      (xdmp:log("Ending profiling"), prof:disable($request-id), prof:report($request-id))
    else
      ()
};

(:
  Render the view result if there's a controller helper map and there
  exists a view.
:)
declare function router:view-result($view, $format) {
  if (fn:exists($ch:map) and fn:exists($view))
  then
    rh:render-view($view, $format, $ch:map)
  else
    ()
};

(:
  Update the controller helper to contain the view
:)
declare function router:set-view-results-in-map($view-result) {
  if (fn:exists($view-result) and fn:not($view-result instance of map:map) and
        fn:not(fn:deep-equal(document {$ch:map}, document {$view-result}))) 
    then
      map:put($ch:map, "view", $view-result)
    else
      map:put($ch:map, "view",
        for $key in map:keys($ch:map)
        return map:get($ch:map, $key))
};

(:
  Compute the final view.
  If we're not bypassing view generation and there's a view or layout
    then 
      Render the view into view-result
      if not bypassing and there's a layout
        then
          return the results from render layout
        else
          return the view result
    else if not buypassing (but not layout or view)
      return the contents of the controller helper
    else return the raw data
:)
declare function router:compute-final-view($view, $layout, $data, $format) {
  let $bypass as xs:boolean := fn:exists($data) and fn:not($data instance of map:map)
  return
    if (fn:not($bypass) and (fn:exists($view) or fn:exists($layout))) 
      then
        let $view-result := router:view-result($view, $format)
        return
          if (fn:not($bypass) and fn:exists($layout)) then
            let $_ := router:set-view-results-in-map($view-result)
            return
              rh:render-layout($layout, $format, $ch:map)
          else
            $view-result
      else if (fn:not($bypass)) then
        for $key in map:keys($ch:map)
        return
          map:get($ch:map, $key)
      else
        $data

};

(:
  Builds a multi-part response with the final view (the rendered response based
  on format, layout, etc.), the profile report, and the expected response
  format.
:)
declare function router:multipart-response($final-view, $profile-report, $format) {
  let $boundary-string := xs:string(xdmp:request())
  return
    (
      xdmp:set-response-content-type("multipart/mixed"),  
      xdmp:multipart-encode( 
      $boundary-string,
      <manifest>
        <part>
          <headers>
            <Content-Type>{rh:lookup-content-type($format)}</Content-Type>
            <boundry>{$boundary-string}</boundry>
          </headers>
        </part>
        <part>
          <headers>
            <Content-Type>vnd.x-ml-profile/xml</Content-Type>
          </headers>
        </part>
      </manifest>,
      ($final-view, $profile-report)))
};

(:
 Main entry point into the routing function
:)
declare function router:route()
{

  (:
    If the ML-X-Profile header is set to 'yes', collect profiling information.  Otherwise,
    we only have the returned data as normal.
  :)
  let $request-id := router:start-profiling()
  let $data :=  
    xdmp:apply(
      xdmp:function(
        fn:QName(fn:concat("http://marklogic.com/roxy/controller/", $controller), $func),
        $controller-path))
  let $profile-report := router:end-profiling($request-id)
  
  (: Roxy options :)
  let $options :=
    for $key in map:keys($ch:map)
    where fn:starts-with($key, "ch:config-")
    return
      map:get($ch:map, $key)

  (: remove options from the data :)
  let $_ :=
    for $key in map:keys($ch:map)
    where fn:starts-with($key, "ch:config-")
    return
      map:delete($ch:map, $key)

  let $format as xs:string := ($options[self::ch:config-format][ch:formats/ch:format = $format]/ch:format, $format)[1]
  (: let $_ := rh:set-content-type($format) :)

  (: controller override of the view :)
  let $view := ($options[self::ch:config-view][ch:formats/ch:format = $format]/ch:view, $default-view)[1][. ne ""]

  (: controller override of the layout :)
  let $layout :=
    if (fn:exists($options[self::ch:config-layout][ch:formats/ch:format = $format])) then
      $options[self::ch:config-layout][ch:formats/ch:format = $format]/ch:layout[. ne ""]
    else
      $default-layout

  let $_ := xdmp:log("computing final result")
  (:
    Compute the final view depending on the layout, view, data and format.  This is what will
    be returned to the consumer.  If there is a profile report, then return a multipart 
    response with the profiling information.
  :)
  let $final-view := router:compute-final-view($view, $layout, $data, $format)
  return 
    if (fn:exists($profile-report))
      then
        router:multipart-response($final-view, $profile-report, $format)
      else
        (rh:set-content-type($format), $final-view)

};