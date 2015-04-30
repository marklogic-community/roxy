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

module namespace rh = 'http://marklogic.com/roxy/routing-helper';

import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

import module namespace c = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";

declare namespace vh = "http://marklogic.com/roxy/view-helper";

declare option xdmp:mapping "false";

declare function rh:render-view($view as xs:string, $format as xs:string, $data as map:map)
{
  let $view-path := fn:concat("/app/views/", $view, ".", $format, ".xqy")
  return
    try {
      xdmp:invoke(
        $view-path,
        (xs:QName("vh:map"), $data),
        <options xmlns="xdmp:eval">
          <isolation>same-statement</isolation>
        </options>)
    }
    catch($ex) {
      if (($ex/error:name, $ex/error:code) = ("SVC-FILOPN", "XDMP-MODNOTFOUND") and
          $ex/error:data/error:datum = u:build-uri(xdmp:modules-root(), $view-path)) then
        fn:error(xs:QName("MISSING-VIEW"), "")
      else
        xdmp:rethrow()
    }
};

declare function rh:render-layout($layout as xs:string, $format as xs:string, $data as map:map)
{
  let $layout-path := fn:concat("/app/views/layouts/", $layout, ".", $format, ".xqy")
  return
    try {
      xdmp:invoke(
        $layout-path,
        (xs:QName("vh:map"), $data),
        <options xmlns="xdmp:eval">
          <isolation>same-statement</isolation>
        </options>)
    }
    catch($ex) {
      if (($ex/error:name, $ex/error:code) = ("SVC-FILOPN", "XDMP-MODNOTFOUND") and
          $ex/error:data/error:datum = u:build-uri(xdmp:modules-root(), $layout-path)) then
        fn:error(xs:QName("MISSING-LAYOUT"), "")
      else
        xdmp:rethrow()
    }
};
declare function rh:set-content-type($format)
{
  let $type as xs:string? := $c:ROXY-OPTIONS/formats/format[@name = $format]/@type/fn:string(.)
  return 
    if (fn:exists($type)) then
      xdmp:set-response-content-type($type)
    else if ($format eq "xml") then
      xdmp:set-response-content-type("application/xml")
    else if ($format eq "html") then
      xdmp:set-response-content-type("text/html")
    else if ($format eq "json") then
      xdmp:set-response-content-type("application/json")
    else if ($format eq "text") then
      xdmp:set-response-content-type("text/plain")
    else
      xdmp:set-response-content-type($format)
};