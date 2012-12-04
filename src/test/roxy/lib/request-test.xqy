xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

declare option xdmp:mapping "false";

declare variable $options :=
  <options xmlns="xdmp:http">
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
    <format xmlns="xdmp:document-get">xml</format>
  </options>;

declare variable $route-options :=
  <routes xmlns="http://marklogic.com/appservices/rest">
    <request resource="geocoder" />
    <request uri="^/test/(js|img|css)/(.*)" />
    <request uri="^/test/(.*)" endpoint="/test/default.xqy">
      <uri-param name="func" default="main">$1</uri-param>
    </request>
    <request uri="^/test$" redirect="/test/" />
    <request uri="^/(css|js|images)/(.*)" endpoint="/public/$1/$2"/>
    <request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/query-router.xqy">
      <uri-param name="controller" default="appbuilder">$1</uri-param>
      <uri-param name="func" default="main">$2</uri-param>
      <uri-param name="format">$3</uri-param>
      <http method="GET"/>
    </request>
    <request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/update-router.xqy">
      <uri-param name="controller" default="appbuilder">$1</uri-param>
      <uri-param name="func" default="main">$2</uri-param>
      <uri-param name="format">$3</uri-param>
      <http method="POST"/>
      <http method="PUT"/>
    </request>
    <request uri="^.+$"/>
  </routes>;

declare function t:setup()
{
  t:load-test-file(
    "test-request.xqy",
    xdmp:modules-database(),
    fn:concat(xdmp:modules-root(), "app/controllers/test-request.xqy"))
};

declare function t:test1()
{
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
  let $response := t:http-get($uri, $options)
  let $_ := xdmp:log($response[2])
  return
    $response[2]/*:results/*
};


declare function t:rewrite-get()
{
  let $url := "/test/js/blah.js"
  let $path := "/test/js/blah.js"
  let $verb := "GET"
  return
    t:assert-equal("/test/js/blah.js", req:rewrite($url, $path, $verb, $route-options)),

  let $url := "/js/blah.js"
  let $path := "/js/blah.js"
  let $verb := "GET"
  return
    t:assert-equal("/public/js/blah.js", req:rewrite($url, $path, $verb, $route-options)),

  let $url := "/controller/func?param1=1&amp;param2=2"
  let $path := "/controller/func"
  let $verb := "GET"
  return
    t:assert-equal(
      "/roxy/query-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:rewrite-post()
{
  let $url := "/controller/func?param1=1&amp;param2=2"
  let $path := "/controller/func"
  let $verb := "POST"
  return
    t:assert-equal(
      "/roxy/update-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:rewrite-put()
{
  let $url := "/controller/func?param1=1&amp;param2=2"
  let $path := "/controller/func"
  let $verb := "PUT"
  return
    t:assert-equal(
      "/roxy/update-router.xqy?controller=controller&amp;func=func&amp;param1=1&amp;param2=2",
      req:rewrite($url, $path, $verb, $route-options)),

  let $url := "/do/some/stuff.xqy?param1=1&amp;param2=2"
  let $path := "/do/some/stuff.xqy"
  let $verb := "PUT"
  return
    t:assert-equal(
      "/do/some/stuff.xqy?param1=1&amp;param2=2",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-index()
{
  (: TEST the Rails resource routes :)
  let $url := "/geocoder"
  let $path := "/geocoder"
  let $verb := "GET"
  return
    t:assert-equal(
      "/roxy/query-router.xqy?controller=geocoder&amp;func=index",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-new()
{
  (: TEST the Rails resource routes :)
  let $url := "/geocoder/new"
  let $path := "/geocoder/new"
  let $verb := "GET"
  return
    t:assert-equal(
      "/roxy/query-router.xqy?controller=geocoder&amp;func=new",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-create()
{
  let $url := "/geocoder"
  let $path := "/geocoder"
  let $verb := "POST"
  return
    t:assert-equal(
      "/roxy/update-router.xqy?controller=geocoder&amp;func=create",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-show()
{
  let $url := "/geocoder/5"
  let $path := "/geocoder/5"
  let $verb := "GET"
  return
    t:assert-equal(
      "/roxy/query-router.xqy?controller=geocoder&amp;func=show&amp;id=5",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-edit()
{
  let $url := "/geocoder/5/edit"
  let $path := "/geocoder/5/edit"
  let $verb := "GET"
  return
    t:assert-equal(
      "/roxy/query-router.xqy?controller=geocoder&amp;func=edit&amp;id=5",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-update()
{
  let $url := "/geocoder/5"
  let $path := "/geocoder/5"
  let $verb := "PUT"
  return
    t:assert-equal(
      "/roxy/update-router.xqy?controller=geocoder&amp;func=update&amp;id=5",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:resource-routes-destroy()
{
  let $url := "/geocoder/5"
  let $path := "/geocoder/5"
  let $verb := "DELETE"
  return
    t:assert-equal(
      "/roxy/update-router.xqy?controller=geocoder&amp;func=destroy&amp;id=5",
      req:rewrite($url, $path, $verb, $route-options))
};

declare function t:teardown()
{
  if (xdmp:modules-database() ne 0) then
    xdmp:eval('
      xquery version "1.0-ml";
      xdmp:document-delete("/app/controllers/test-request.xqy")',
      (),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
      </options>)
  else ()
};
