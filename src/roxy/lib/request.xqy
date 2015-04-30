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

(:
 : A set of functions to assist in building a RESTful framework
 :)
xquery version "1.0-ml";

module namespace req = "http://marklogic.com/roxy/request";

import module namespace r = "http://marklogic.com/roxy/reflection" at "/roxy/lib/reflection.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

declare option xdmp:mapping "false";

(: Builds a map containing request field names and their values :)
declare variable $req:request as map:map :=
  let $map := map:map()
  return
  (
    for $name as xs:string in xdmp:get-request-field-names()
    let $current := map:get($map, $name)
    let $vals :=
      for $val in xdmp:get-request-field($name)
    return
        if ($val instance of xs:anySimpleType) then
          $val
        else (
          if ($val instance of binary()) then
            map:put($map, fn:concat($name, "-filename"), xdmp:get-request-field-filename($name))
          else (),
          $val
        )
    return
      if (fn:exists($current)) then
        map:put($map, $name, ($current, $vals))
      else
      map:put($map, $name, $vals),
    $map
  )
;

(:~
 : Retrieves the value of a request field, if it exists
 :
 : @param $name - the name of the request field
 : @return - the value of the request field if it exists
 :)
declare function req:get($name as xs:string) as item()*
{
  req:get($name, (), ())
};

(:~
 : Retrieves the value of a request field, if it exists
 :
 : @param $name - the name of the request field
 : @param $options - additional options for the get
 :    Valid options:
 :      - type=(xs:string, xs:int, xs:boolean, ...)
 :        throws an error if the passed-in value is not of the type provided
 :        Note that the error is not thrown if no value is provided
 :        xml causes the value to be passed through xdmp:unquote
 :
 :      - max-count=some number
 :        throws an error if the number of values exceeds the value provided
 :
 :      - allow-empty=(true, false) when used with a string parameter
 :        prevents empty "" strings from going into the value(s)
 :
 : @return - the value of the request field if it exists
 :)
declare function req:get(
  $name as xs:string,
  $options as xs:string*) as item()*
{
  req:get($name, (), $options)
};

(:~
 : Retrieves the value of a request and returns the value if it exists or the supplied default otherwise
 :
 : @param $name - the name of the request field
 : @param $default - the default value to use when the field is not present
 : @param $options - additional options for the get
 :    Valid options:
 :      - type=(xml, xs:string, xs:int, xs:boolean, ...)
 :        throws an error if the passed-in value is not of the type provided
 :        Note that the error is not thrown if no value is provided
 :        xml causes the value to be passed through xdmp:unquote
 :
 :      - max-count=some number
 :        throws an error if the number of values exceeds the value provided
 :
 :      - allow-empty=(true, false) when used with a string parameter
 :        prevents empty "" strings from going into the value(s)
 :
 : @return - the value of the request field if it exists or $default otherwise
 : @throws - an exception if
 :            - the field is not of the correct type
 :            - the field exceeds the maximum value count
 :)
declare function req:get(
  $name as xs:string,
  $default as item()*,
  $options as xs:string*) as item()*
{
  let $type as xs:string? :=
    (:
     : cast as only works with ?, not + or *
     : http://www.w3.org/TR/xquery/#id-cast
    :)
    let $t as xs:string? := req:get-option($options, "type", "xs:string")
    where $t
    return
      if (fn:ends-with($t, "+")) then
        fn:substring($t, 1, fn:string-length($t) - 1)
      else if (fn:ends-with($t, "*")) then
        fn:replace($t, "^(.*)\*$", "$1?")
      else
        $t
  let $max-count as xs:int? := req:get-option($options, "max-count", "xs:int")
  let $allow-empty as xs:boolean :=
    (
      req:get-option($options, "allow-empty", "xs:boolean"),
      fn:true()
    )[1]
  let $item :=
    for $value in map:get($req:request, $name)
    return
      if (fn:exists($value) and $type eq 'xml') then
        let $v :=
          try
          {
            xdmp:unquote($value[. ne ''])
          }
          catch($ex) {()}
        return
          if (fn:exists($v)) then $v/*
          else
            fn:error(xs:QName("INVALID-REQUEST-PARAMETER"), fn:concat($name, "=", $value), "response-code=400")
      else if (fn:exists($value) and $type) then
        let $v := req:cast-as-type($value, $type)
        return
          if (fn:exists($v)) then
            $v
          else
            fn:error(xs:QName("INVALID-REQUEST-PARAMETER"), fn:concat($name, "=", $value), "response-code=400")
      else
        $value
  return
    if (fn:exists($item)) then
    (
      req:assert-max-count($name, $item, $max-count),
      if ($type eq "xs:string") then
        if ($allow-empty) then
          $item
        else
          let $item := $item[. ne ""]
          return
            if ($item) then $item
            else $default
      else
      $item
    )
    else
      $default
};

(:~
 : Asserts that the maximum number of parameters has not been exceeded
 :
 : @return - empty sequence if ok, throws error otherwise
 :)
declare private function req:assert-max-count(
  $name as xs:string,
  $item as item()*,
  $max-count as xs:int?) as empty-sequence()
{
  if (fn:exists($max-count) and fn:count($item) > $max-count) then
    fn:error(
      xs:QName("TOO-MANY-VALUES"),
      fn:concat("Too many values provided for parameter: ", $name),
      "response-code=400")
  else ()
};

(:~
 : Parses out a value from the supplied options sequence into the requested data type
 :
 : @param $options - a sequence of strings
 : @param $name - the name of the option to retrieve
 : @param $type - the data type to return the value as (xs:string, xs:int, etc...)
 : @return either a value in the requested data type or the empty sequence
 :)
declare private function req:get-option(
  $options as xs:string*,
  $name as xs:string,
  $type as xs:string) as item()?
{
  let $value :=
    let $o := $options[fn:matches(., fn:concat($name, "=.*"))]
    return
      fn:replace($o, fn:concat($name, "=(.*)"), "$1")
  return
    if ($value) then
      req:cast-as-type($value, $type)
    else ()
};

(:~
 : Asserts the existence of a request field returning it's value if it does exist
 : and throwing an exception otherwise
 :
 : @param $name - the name of the request field
 : @return - the value of the request field if it exists
 : @throws - an exception if the field is not present
 :)
declare function req:required($name as xs:string) as item()*
{
  req:required($name, ())
};

(:~
 : Asserts the existence of a request field returning it's value if it does exist
 : and throwing an exception otherwise
 :
 : @param $name - the name of the request field
 : @param $options - options for the get
 : @return - the value of the request field if it exists
 : @throws - an exception if the field is not present
 :)
declare function req:required(
  $name as xs:string,
  $options as xs:string*) as item()*
{
  let $value := req:get($name, $options)
  return
    if (fn:exists($value)) then
      $value
    else
      fn:error(
        xs:QName("MISSING-CONTROLLER-PARAM"),
        fn:concat("Required parameter '", $name, "' is missing"),
        ($name, $r:__CALLER_FILE__))
};

(:~
 : Asserts that the current verb matchs the supplied verb name(s)
 :
 : @param $verbs - name(s) of verbs to allow for this request
 : @return - empty sequence () if the verb matches
 : @throws - an exception if the verb doesn't match
 :)
declare function req:require-verb($verbs as xs:string+) as empty-sequence()
{
  if (xdmp:get-request-method() = $verbs) then ()
  else
    fn:error(xs:QName("INVALID-VERB"), fn:concat("Required HTTP verb: ", $verbs))
};

(:
 : Attempts to cast the given value as the given type
 :
 : @param $value - the value to cast
 : @param $type - the type to cast as
 : @return - zero or more items
 :)
declare private function req:cast-as-type(
  $value as xs:string,
  $type as xs:string) as item()*
{
  let $validate :=
    if (fn:ends-with($type, "?")) then
      xs:QName(fn:substring($type, 1, fn:string-length($type) - 1))
    else
      xs:QName($type)
  return
    if (xdmp:value(fn:concat("$value castable as ", $type))) then
      xdmp:value(fn:concat("$value cast as ", $type))
    else
      ()
};

declare function req:expand-resources($nodes)
{
  for $n in $nodes
  return
    typeswitch ($n)
      case element(rest:request) return
        if ($n/@resource) then
          let $res as xs:string := $n/@resource
          return
          (
            <rest:request uri="{fn:concat('^/', $res, '\.?(\w*)$')}" endpoint="/roxy/query-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">index</rest:uri-param>
              <rest:uri-param name="format">$1</rest:uri-param>
              <rest:http method="GET"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '/new\.?(\w*)$')}" endpoint="/roxy/query-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">new</rest:uri-param>
              <rest:uri-param name="format">$1</rest:uri-param>
              <rest:http method="GET"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '\.?(\w*)$')}" endpoint="/roxy/update-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">create</rest:uri-param>
              <rest:uri-param name="format">$2</rest:uri-param>
              <rest:http method="POST"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '/([\w\d_\-]*)\.?(\w*)$')}" endpoint="/roxy/query-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">show</rest:uri-param>
              <rest:uri-param name="format">$2</rest:uri-param>
              <rest:uri-param name="id">$1</rest:uri-param>
              <rest:http method="GET"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '/([\w\d_\-]*)/edit\.?(\w*)$')}" endpoint="/roxy/query-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">edit</rest:uri-param>
              <rest:uri-param name="format">$2</rest:uri-param>
              <rest:uri-param name="id">$1</rest:uri-param>
              <rest:http method="GET"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '/([\w\d_\-]*)\.?(\w*)$')}" endpoint="/roxy/update-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">update</rest:uri-param>
              <rest:uri-param name="format">$2</rest:uri-param>
              <rest:uri-param name="id">$1</rest:uri-param>
              <rest:http method="PUT"/>
            </rest:request>,
            <rest:request uri="{fn:concat('^/', $res, '/([\w\d_\-]*)\.?(\w*)$')}" endpoint="/roxy/update-router.xqy">
              <rest:uri-param name="controller">{$res}</rest:uri-param>
              <rest:uri-param name="func">destroy</rest:uri-param>
              <rest:uri-param name="format">$2</rest:uri-param>
              <rest:uri-param name="id">$1</rest:uri-param>
              <rest:http method="DELETE"/>
            </rest:request>
          )
        else
          $n
      case element() return
        element { fn:node-name($n) }
        {
          req:expand-resources(($n/@*, $n/node()))
        }
      default return $n
};

declare function req:build-params($matching-request, $url, $path)
{
  fn:string-join((
    for $param in $matching-request/*:uri-param
    let $value as xs:string? :=
      fn:replace($path, $matching-request/@uri, $param)
    let $value as xs:string? :=
      if ($value) then
        $value
      else if ($param/@default) then
        $param/@default
      else ()
    return
      if ($value) then
        fn:concat($param/@name, "=", $value)
      else (),
    fn:substring-after($url, "?")[. ne ""]),
    "&amp;")
};

declare function req:rewrite($url, $path, $verb, $routes as element(rest:routes)) as xs:string?
{
  let $routes := req:expand-resources($routes)
  let $matching-request :=
    (
      $routes/*:request[fn:matches($path, @uri)]
                       [if (*:http/@method) then $verb = *:http/@method
                        else fn:true()]
    )[1]
  let $final-uri as xs:string? :=
    if ($matching-request) then
      if ($matching-request/@redirect) then
      (
        xdmp:redirect-response(
          let $params := req:build-params($matching-request, $url, $path)
          return
            fn:concat(
              $matching-request/@redirect,
              if ($params) then "?"
              else (),
              $params
            )),
        (: This needs to point to a main module :)
        "/roxy/no-op.xqy"
      )
      else if ($matching-request/@endpoint) then
        let $params := req:build-params($matching-request, $url, $path)
        return
          fn:concat(
            fn:replace($path, $matching-request/@uri, $matching-request/@endpoint),
            if ($params) then "?"
            else (),
            $params)
      else ()
    else ()
  return
    $final-uri
};

declare function req:is-ajax-request() as xs:boolean
{
  xdmp:get-request-header("X-Requested-With") = "XMLHttpRequest"
};