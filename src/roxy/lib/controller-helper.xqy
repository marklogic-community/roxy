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

module namespace ch = 'http://marklogic.com/roxy/controller-helper';

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/roxy/request" at
 "/roxy/lib/request.xqy";

declare option xdmp:mapping "false";

declare variable $ALL-FORMATS as xs:string+ := ("html", "xml", "json", "text");

declare variable $ch:map as map:map := map:map();

declare function ch:use-view($view as xs:string?)
{
  ch:use-view($view, $ALL-FORMATS)
};

declare function ch:use-view($view as xs:string?, $formats as xs:string*)
{
  map:put(
    $ch:map,
    "ch:config-view",
    (
      map:get($ch:map, "ch:config-view"),
      element ch:config-view
      {
        element ch:formats
        {
          for $format in $formats
          return
            element ch:format { $format }
        },
        element ch:view { $view }
      }
    )
  )
};

declare function ch:use-layout($layout as xs:string?)
{
  ch:use-layout($layout, $ALL-FORMATS)
};

declare function ch:use-layout($layout as xs:string?, $formats as xs:string*)
{
  map:put(
    $ch:map,
    "ch:config-layout",
    (
      map:get($ch:map, "ch:config-layout"),
      element ch:config-layout
      {
        element ch:formats
        {
          for $format in $formats
          return
            element ch:format { $format }
        },
        element ch:layout { $layout }
      }
    )
  )
};

declare function ch:add-value($key as xs:string, $default as item()*)
{
  map:put($ch:map, $key, (map:get($ch:map, $key), $default))
};

declare function ch:add-value($key as xs:string)
{
  ch:add-value($key, req:get($key))
};

declare function ch:set-value($key as xs:string, $value as item()*)
{
  map:put($ch:map, $key, $value)
};

declare function ch:set-value($key as xs:string)
{
  map:put($ch:map, $key, req:get($key))
};

declare function ch:get($key as xs:string)
{
  map:get($ch:map, $key)
};

declare function ch:set-format($new-format as xs:string)
{
  ch:set-format($new-format, $ALL-FORMATS)
};

declare function ch:set-format($new-format as xs:string, $formats as xs:string*)
{
  map:put(
    $ch:map,
    "ch:config-format",
    (
      map:get($ch:map, "ch:config-layout"),
      element ch:config-format
      {
        element ch:formats
        {
          for $format in $formats
          return
            element ch:format { $format }
        },
        element ch:format { $new-format }
      }
    )
  )
};

declare function ch:http-error($error-code as xs:int, $message as xs:string)
{
  ch:http-error($error-code, $message, ())
};

declare function ch:http-error($error-code as xs:int, $message as xs:string, $body)
{
  fn:error((), "HTTP-ERROR", ($error-code, $message, $body))
};
