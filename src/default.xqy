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

import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/lib/controller-helper.xqy";
import module namespace config = "http://marklogic.com/ns/config" at "/app/config/config.xqy";
import module namespace req = "http://marklogic.com/framework/request" at "/lib/request.xqy";
import module namespace rh = "http://marklogic.com/roxy/routing-helper" at "/lib/routing-helper.xqy";

declare option xdmp:mapping "false";

declare variable $controller as xs:string := req:get("controller", "", "type=xs:string");
declare variable $controller-namespace as xs:string := fn:concat("http://marklogic.com/roxy/controller/", $controller);
declare variable $controller-path as xs:string := fn:concat("/app/controllers/", $controller, ".xqy");
declare variable $func as xs:string := req:get("func", "index", "type=xs:string");
declare variable $format as xs:string := req:get("format", $config:DEFAULT-FORMAT, "type=xs:string");
declare variable $default-view as xs:string := fn:concat($controller, "/", $func);

(: assume no default layout for xml, json, text :)
declare variable $default-layout as xs:string? := map:get($config:DEFAULT-LAYOUTS, $format);

try
{
  let $map := map:map()
  let $data :=
    xdmp:invoke($controller-path, (
      xs:QName("function-QName"), fn:QName($controller-namespace, $func),
      xs:QName("ch:map"), $map
    ))

  (: framework options :)
  let $options :=
    for $key in map:keys($map)
    where fn:starts-with($key, "ch:config-")
    return
      map:get($map, $key)

  (: remove options from the data :)
  let $_ :=
    for $key in map:keys($map)
      where fn:starts-with($key, "ch:config-")
      return
      map:delete($map, $key)

  let $format as xs:string := ($options[self::ch:config-format][ch:formats/ch:format = $format]/ch:format, $format)[1]
  let $_ := rh:set-content-type($format)

  (: controller override of the view :)
  let $view := ($options[self::ch:config-view][ch:formats/ch:format = $format]/ch:view, $default-view)[1][. ne ""]

  (: controller override of the layout :)
  let $layout :=
    if (fn:exists($options[self::ch:config-layout][ch:formats/ch:format = $format])) then
      $options[self::ch:config-layout][ch:formats/ch:format = $format]/ch:layout[. ne ""]
    else
      $default-layout

  (: if the view return something other than the map or () then bypass the view and layout :)
  let $bypass as xs:boolean := fn:exists($data) and fn:not($data instance of map:map) (: fn:not(fn:deep-equal(document {$data}, document {$map})) :)

  return
    if (fn:not($bypass) and (fn:exists($view) or fn:exists($layout))) then
      let $view-result :=
        if (fn:exists($map) and fn:exists($view)) then
          rh:render-view($view, $format, $map)
        else
          ()
      return
        if (fn:not($bypass) and fn:exists($layout)) then
          let $_ :=
            if (fn:exists($view-result) and fn:not($view-result instance of map:map) and fn:not(fn:deep-equal(document {$map}, document {$view-result}))) then
              map:put($map, "view", $view-result)
            else
              map:put($map, "view",
                for $key in map:keys($map)
                return
                  map:get($map, $key))
          return
            rh:render-layout($layout, $format, $map)
        else
          $view-result
    else if (fn:not($bypass)) then
      for $key in map:keys($map)
      return
        map:get($map, $key)
    else
      $data
}
catch($ex)
{
  if ($ex/error:code = "XDMP-UNDVAR" and $ex/error:data/error:datum = "$c:map") then
    fn:error(xs:QName("MISSING-MAP"), fn:concat("Missing external map declaration in ", $controller-path), $controller-path)
  else
    xdmp:rethrow()
}