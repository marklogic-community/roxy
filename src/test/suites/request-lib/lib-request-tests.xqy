xquery version "1.0-ml";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";
import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

declare option xdmp:mapping "false";

declare variable $options :=
  <options xmlns="xdmp:http">
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
    <format xmlns="xdmp:document-get">xml</format>
  </options>;

declare variable  $route-options :=
  <rest:options>
    <rest:request uri="^/test/(js|img|css)/(.*)" />
    <rest:request uri="^/test/(.*)" endpoint="/test/default.xqy">
      <rest:uri-param name="func" default="main">$1</rest:uri-param>
    </rest:request>
    <rest:request uri="^/test$" redirect="/test/" />
    <rest:request uri="^/(css|js|images)/(.*)" endpoint="/public/$1/$2"/>
    <rest:request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/query-router.xqy">
      <rest:uri-param name="controller" default="appbuilder">$1</rest:uri-param>
      <rest:uri-param name="func" default="main">$2</rest:uri-param>
      <rest:uri-param name="format">$3</rest:uri-param>
      <rest:http method="GET"/>
    </rest:request>
    <rest:request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/update-router.xqy">
      <rest:uri-param name="controller" default="appbuilder">$1</rest:uri-param>
      <rest:uri-param name="func" default="main">$2</rest:uri-param>
      <rest:uri-param name="format">$3</rest:uri-param>
      <rest:http method="POST"/>
      <rest:http method="PUT"/>
    </rest:request>
    <rest:request uri="^.+$"/>
  </rest:options>;

let $uri := 
  fn:concat(
    "/test-request/test1?",
    "valid=yes",
    "&amp;dt=", fn:current-dateTime(),
    "&amp;number=1234",
    "&amp;invalidnumber=notnum",
    "&amp;single=val1",
    "&amp;single=val2",
    "&amp;sequence=a",
    "&amp;sequence=b",
    "&amp;sequence=c",
    "&amp;hasquote=", fn:encode-for-uri("has""quote""indeed"),
    "&amp;x1=<test/>",
    "&amp;x2=<<busted-xml/>",
    "&amp;empty=")
let $_ := xdmp:log(("URI:", $uri))
let $response := test:http-get($uri, $options)
return
  $response[2]/*:results/*,

let $url := "/test/js/blah.js"
let $path := "/test/js/blah.js"
let $verb := "GET"
return
  test:assert-equal("/test/js/blah.js", req:rewrite($url, $path, $verb, $route-options)),

let $url := "/js/blah.js"
let $path := "/js/blah.js"
let $verb := "GET"
return
  test:assert-equal("/public/js/blah.js", req:rewrite($url, $path, $verb, $route-options)),

let $url := "/controller/func?param1=1&amp;param2=2"
let $path := "/controller/func"
let $verb := "GET"
return
  test:assert-equal(
    "/roxy/query-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
    req:rewrite($url, $path, $verb, $route-options)),

let $url := "/controller/func?param1=1&amp;param2=2"
let $path := "/controller/func"
let $verb := "POST"
return
  test:assert-equal(
    "/roxy/update-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
    req:rewrite($url, $path, $verb, $route-options)),

let $url := "/controller/func?param1=1&amp;param2=2"
let $path := "/controller/func"
let $verb := "PUT"
return
  test:assert-equal(
    "/roxy/update-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
    req:rewrite($url, $path, $verb, $route-options)),

let $url := "/do/some/stuff.xqy?param1=1&amp;param2=2"
let $path := "/do/some/stuff.xqy"
let $verb := "PUT"
return
  test:assert-equal(
    "/do/some/stuff.xqy?param1=1&amp;param2=2",
    req:rewrite($url, $path, $verb, $route-options))