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

import module namespace u = "http://marklogic.com/framework/util" at "/lib/util.xqy";

import module namespace config = "http://marklogic.com/ns/config" at "/app/config/config.xqy";
import module namespace soap = "http://marklogic/roxy/soap" at "/lib/soap-lib.xqy";

declare namespace s="http://www.w3.org/2009/xpath-functions/analyze-string";

declare variable $TEMPLATE-REGEX as xs:string := "^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$";

declare function local:build-controller-url($url, $path, $params, $soap-call)
{
  let $analysis := fn:analyze-string($path, $TEMPLATE-REGEX)
  let $controller := ($analysis/s:match/s:group[@nr eq 1][. ne ""], $config:DEFAULT-CONTROLLER)[1]
  let $func :=
    if ($soap-call) then
      soap:get-op-name(xdmp:get-request-body())
    else
      (($analysis/s:match/s:group[@nr eq 2])[. ne ""], if ($controller eq "") then "index" else "main")[1]
  let $format := $analysis/s:match/s:group[@nr eq 3][. ne ""]
  return
    if ($controller ne "") then
      if (u:module-file-exists(concat("/app/controllers/", $controller, ".xqy"))) then
        concat(
          "/default.xqy?controller=",
          $controller,
          "&amp;func=",
          $func,
          if ($format) then concat("&amp;format=", $format) else (),
          if ($params) then concat("&amp;", $params) else ())
      else
        $url
    else
      "/public/index.html"
};

let $url := xdmp:get-request-url()
let $path := xdmp:get-request-path()
let $naked-path := fn:replace($path, "/(.*)", "$1")
let $params := substring-after($url, "?")[. ne ""]
return
  if (matches($url, "^/test$")) then
  (
    xdmp:redirect-response("/test/"), $url
  )
  else if (matches($url, "^/test/")) then
    if (matches($url, "(js|img|css)")) then $url
    else
      let $func := (tokenize($path, "/")[3][. ne ""], "main")[1]
      return
        concat("/test/default.xqy?func=", $func, if ($params) then concat("&amp;", $params) else ())
  (: rewrite for resources :)
  else if (matches($url, "^/(css|js|images)/")) then
      concat("/public", $url)
  else if (u:module-file-exists(concat('/public', $path, '.html'))) then
    concat("/public", $url, '.html')
  else if (u:module-file-exists(concat('/public/', $path))) then
    concat("/public/", $url)
  else if ($config:ALIASES/alias[@uri = $naked-path]) then
    let $endpoint as xs:string+ := fn:tokenize($config:ALIASES/alias[@uri = $naked-path]/@endpoint, "/")
    let $controller := $endpoint[1]
    let $func := $endpoint[2]
    let $format := "html"
    return
      if (u:module-file-exists(concat("/app/controllers/", $controller, ".xqy"))) then
        concat(
          "/default.xqy?controller=",
          $controller,
          "&amp;func=",
          $func,
          if ($format) then concat("&amp;format=", $format) else (),
          if ($params) then concat("&amp;", $params) else ())
      else
        $url
  else if (fn:matches($url, "^/soap/")) then (
    local:build-controller-url($url, fn:replace($path, "/soap", ""), $params, fn:true())
  )
  (: rewrite rest routing :)
  else if (matches($path, $TEMPLATE-REGEX)) then
    local:build-controller-url($url, $path, $params, fn:false())
  else
    $url