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

(:
 : A set of functions to assist in building a RESTful framework
 :)
xquery version "1.0-ml";

module namespace req = "http://marklogic.com/framework/request";

import module namespace r = "http://marklogic.com/roxy/reflection" at "/lib/reflection.xqy";

declare option xdmp:mapping "false";

(: Builds a map containing request field names and their values :)
declare variable $req:request as map:map :=
  let $map := map:map()
  return
  (
    for $name as xs:string in xdmp:get-request-field-names()
    let $current := map:get($map, $name)
    return
      if (fn:exists($current)) then
        map:put($map, $name, ($current, xdmp:get-request-field($name)))
      else
      map:put($map, $name, xdmp:get-request-field($name)),
    $map
  )
;

(:~
 : Retrieves the value of a request field, if it exists
 :
 : @param $name - the name of the request field
 : @return - the value of the request field if it exists
 :)
declare function req:get($name as xs:string) as item()* {
  req:get($name, (), ())
};

(:~
 : Retrieves the value of a request field, if it exists
 :
 : @param $name - the name of the request field
 : @param $options - additional options for the get
 :    Valid options:
 :      - type=(xs:string, xs:int, xs:boolean, ...)
 :      - validate=(true, false) NOTE: you must supply a type for validate to work
 :
 : @return - the value of the request field if it exists
 :)
declare function req:get($name as xs:string, $options as xs:string*) as item()* {
  req:get($name, (), $options)
};

(:~
 : Retrieves the value of a request and returns the value if it exists or the supplied default otherwise
 :
 : @param $name - the name of the request field
 : @param $default - the default value to use when the field is not present
 : @param $options - additional options for the get
 :    Valid options:
 :      - type=(xs:string, xs:int, xs:boolean, ...)
 :      - validate=(true, false) NOTE: you must supply a type for validate to work
 :
 : @return - the value of the request field if it exists or $default otherwise
 :)
declare function req:get($name as xs:string, $default as item()*, $options as xs:string*) as item()* {
  let $type as xs:string? := req:get-option($options, "type", "xs:string")
  let $validate as xs:boolean? := req:get-option($options, "validate", "xs:boolean")
  let $max-count as xs:int? := req:get-option($options, "max-count", "xs:int")
  let $allow-empty as xs:boolean := (req:get-option($options, "allow-empty", "xs:boolean"), fn:true())[1]
  let $item :=
    let $value := map:get($req:request, $name)
    return
      if (fn:exists($value) and $type eq 'xml') then
        let $v :=
        try {
            xdmp:unquote($value[. ne ''])
          }
          catch($ex){()}
        return
          if (fn:exists($v)) then $v/*
          else $default
      else if ($value and $type) then
        try
        {
          (: Ensure $type is a valid QName before putting it through xdmp:value() :)
          let $_ := xs:QName($type)
          return
            xdmp:value(fn:concat('"', fn:replace(fn:replace($value, '"', '""'), "&amp;", "&amp;amp;"), '" cast as ', $type))
        }
        catch($ex)
        {
          req:assert-max-count($name, $value, $max-count),
          if ($validate eq fn:true()) then
            fn:error(xs:QName("INVALID-REQUEST-PARAMETER"), fn:concat($name, "=", $value), "response-code=400")
          else ()
        }
      else
        $value
  return
    if (fn:exists($item)) then
    (
      req:assert-max-count($name, $item, $max-count),
      if ($type eq "xs:string") then
         if ($allow-empty) then $item
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
  $max-count as xs:int?) as empty-sequence() {
  if (fn:not(fn:exists($max-count)) or fn:count($item) <= $max-count) then
    ()
  else
    fn:error(xs:QName("TOO-MANY-VALUES"), fn:concat("Too many values provided for parameter: ", $name), "response-code=400")
};

(:~
 : Parses out a value from the supplied options sequence into the requested data type
 :
 : @param $options - a sequence of strings
 : @param $name - the name of the option to retrieve
 : @param $type - the data type to return the value as (xs:string, xs:int, etc...)
 : @return either a value in the requested data type or the empty sequence
 :)
declare private function req:get-option($options as xs:string*, $name as xs:string, $type as xs:string) as item()? {
  let $value :=
    let $o := $options[fn:matches(., fn:concat($name, "=.*"))]
    return
      fn:replace($o, fn:concat($name, "=(.*)"), "$1")
  return
    if ($value) then
      try {
        xdmp:value(fn:concat('"', $value, '" cast as ', $type))
      }
      catch($ex) {()}
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
declare function req:required($name as xs:string, $options as xs:string*) as item()*
{
  let $value := req:get($name, $options)
  return
  	if (fn:exists($value)) then
  		$value
  	else
  		fn:error(xs:QName("MISSING-CONTROLLER-PARAM"), fn:concat("Required parameter '", $name, "' is missing"), ($name, $r:__CALLER_FILE__))
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

(:~
 : Returns the Referrer Header value
 :)
declare function req:referer() as xs:string {
  let $referrer := xdmp:get-request-header("Referer")
  return
    if ($referrer) then $referrer
    else
      fn:error(
        xs:QName("MISSING-REFERER"),
        "Missing Referer field in HTTP Header",
        "response-code=400")
};

declare function req:accepts() as xs:string {
  let $accepts := xdmp:get-request-header("Accept")
  let $accept:=
    if (fn:normalize-space($accepts)) then
      element media-range {
        for $a in fn:tokenize($accepts, ',')
        let $tokens := fn:tokenize($a, ';')
        return
          element range {
            attribute type { fn:normalize-space($tokens[1]) },
            for $t in $tokens[2 to fn:last()]
            return
              if(fn:contains($t, '='))
              then attribute { fn:normalize-space(fn:replace($t, '(.*)=.*', '$1')) } { fn:replace($t, '.*=(.*)', '$1$2') }
              else ()
          }
      }
    else
      element media-range { element range { attribute type { "text/html" } } }

  let $media-range :=
    (for $range in $accept/range
     order by
        fn:min(($range/@q, if(fn:matches($range/@type, '\w+/\*')) then 0.01 else if(fn:matches($range/@type, '\*/\*')) then 0.001 else 1)) descending,
        (for $param in $range/@*[fn:name(.) ne 'type' and fn:name(.) ne 'q']
         return fn:min(($param, 0)))[.] descending
     return fn:distinct-values($range/@type))[1]
  return
    if(fn:exists($media-range)) then
      $media-range
    else
      "text/html"
};