xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare variable $options :=
  <options xmlns="xdmp:http">
    <format xmlns="xdmp:document-get">xml</format>
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
  </options>;

declare variable $options-non-xml :=
  <options xmlns="xdmp:http">
    <authentication method="digest">
      <username>{$c:USER}</username>
      <password>{$c:PASSWORD}</password>
    </authentication>
  </options>;

declare function t:setup()
{
  t:load-test-file("tester.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/controllers/tester.xqy")),
  t:load-test-file("missing-map.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/controllers/missing-map.xqy")),
  t:load-test-file("different-layout-view.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/different-layout.html.xqy")),
  t:load-test-file("different-view-xml-only.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/different-view-xml-only.html.xqy")),
  t:load-test-file("main.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/main.html.xqy")),
  t:load-test-file("main.xml.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/main.xml.xqy")),
  t:load-test-file("missing-variable.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/missing-variable.html.xqy")),
  t:load-test-file("missing-layout.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/missing-layout.html.xqy")),
  t:load-test-file("no-layout.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/no-layout.html.xqy")),
  t:load-test-file("view-with-bad-import.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/view-with-bad-import.html.xqy")),
  t:load-test-file("view-that-returns-the-input.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/tester/view-that-returns-the-input.html.xqy")),
  t:load-test-file("different-layout.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/layouts/different-layout.html.xqy")),
  t:load-test-file("test-layout.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/layouts/test-layout.html.xqy")),
  t:load-test-file("layout-with-bad-import.html.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/views/layouts/layout-with-bad-import.html.xqy")),
  xdmp:document-insert("/delete-me.xml", <or-query><to-be/><not-to-be/></or-query>)
};

declare function t:teardown()
{
  (: remove the test controller and views :)
  if (xdmp:modules-database() ne 0) then
    xdmp:eval('
      xquery version "1.0-ml";
      xdmp:directory-delete("/app/views/tester/"),
      xdmp:document-delete("/app/views/layouts/different-layout.html.xqy"),
      xdmp:document-delete("/app/controllers/tester.xqy")',
      (),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
      </options>)
  else (),

  xdmp:document-delete("/test-insert.xml"),
  xdmp:document-delete("/test-insert2.xml")
};

declare function t:tests()
{

  (: Verify that /tester will call tester:main and return the html view :)
  let $response := xdmp:http-get(t:easy-url("/tester"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("main", fn:string($response[2]//html:title)),
    t:assert-equal("test message: main", fn:string($response[2]//html:div[@id="message"]))
  ),

  (: Verify that the .html will return the html view :)
  let $response := xdmp:http-get(t:easy-url("/tester.html"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("main", fn:string($response[2]//html:title)),
    t:assert-equal("test message: main", fn:string($response[2]//html:div[@id="message"]))
  ),

  (: Verify that the .xml will return the xml view :)
  let $response := xdmp:http-get(t:easy-url("/tester.xml"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("test message: main", fn:string($response[2]/xml))
  ),

  (: JSON view is not defined. Should throw a 500 error with handy error message :)
  let $response := xdmp:http-get(t:easy-url("/tester.json"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Missing the view:tester/main.json"))
  ),

  (: verify that a handy error message is displayed when a layout is missing. :)
  let $response := xdmp:http-get(t:easy-url("/tester/missing-layout"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Layout:i-dont-exist"))
  ),

  (: verify that a handy error message is displayed when a view is missing. :)
  let $response := xdmp:http-get(t:easy-url("/tester/missing-view"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Missing the view:tester/missing-view.html"))
  ),

  (: verify that turning off the layout works :)
  let $response := xdmp:http-get(t:easy-url("/tester/no-layout"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-not-exists($response[2]//html:html),
    t:assert-equal("test message: no-layout", fn:string($response[2]/html:div[@id="message"]))
  ),

  (: verify that turning off the view works :)
  let $response := xdmp:http-get(t:easy-url("/tester/no-view"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-not-exists($response[2]//html:div[@class="content"]/*),
    t:assert-equal("test message: no-view", fn:string($response[2]//html:div[@class="content"]))
  ),

  (: verify that turning off the view and layout works :)
  let $response := xdmp:http-get(t:easy-url("/tester/no-view-or-layout"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("test message: no-view-or-layout", fn:string($response[2]/x))
  ),

  (: verify that specifying a different view works :)
  let $response := xdmp:http-get(t:easy-url("/tester/different-view"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("different-view", fn:string($response[2]//html:title)),
    t:assert-equal("test message: different-view", fn:string($response[2]//html:div[@id="message" and @class="main"]))
  ),

  (: verify that specifying a different layout works :)
  let $response := xdmp:http-get(t:easy-url("/tester/different-layout"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal(1, fn:count($response[2]//html:body[@class="different-layout"])),
    t:assert-equal("test message: different-layout", fn:string($response[2]//html:div[@id="message"]))
  ),

  (: verify that specifying a different view for only xml works - first get html :)
  let $response := xdmp:http-get(t:easy-url("/tester/different-view-xml-only"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("different-view", fn:string($response[2]//html:title)),
    t:assert-equal("test message: different-view", fn:string($response[2]//html:div[@id="message"]))
  ),

  (: verify that specifying a different view for only xml works - now get xml :)
  let $response := xdmp:http-get(t:easy-url("/tester/different-view-xml-only.xml"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal("test message: different-view", fn:string($response[2]/xml))
  ),

  (: verify that returning the input from the view doesn't break anything :)
  let $response := xdmp:http-get(t:easy-url("/tester/view-that-returns-the-input"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-not-exists($response[2]//html:div[@class="content"]/*),
    t:assert-equal("view-that-returns-the-input", fn:string($response[2]//html:div[@class="content"]))
  ),

  (: verify that a missing variable returns a handy error message :)
  let $response := xdmp:http-get(t:easy-url("/tester/missing-variable"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "is expecting the parameter message"))
  ),

  (: verify that a bad import propagates the correct error :)
  let $response := xdmp:http-get(t:easy-url("/tester/layout-with-bad-import"), $options-non-xml)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains($response[2], "SVC-FILOPN") or fn:contains($response[2], "XDMP-MODNOTFOUND"))
  ),

  (: verify that a bad import propagates the correct error :)
  let $response := xdmp:http-get(t:easy-url("/tester/view-with-bad-import"), $options-non-xml)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-true(fn:contains($response[2], "SVC-FILOPN") or fn:contains($response[2], "XDMP-MODNOTFOUND"))
  ),


  (: verify that public resources are accessible :)
  let $response := xdmp:http-get(t:easy-url("/css/app.less"), $options-non-xml)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code))
  ),

  (: verify that public resources are accessible :)
  let $response := xdmp:http-get(t:easy-url("/images/ml-logo.gif"), $options-non-xml)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code))
  ),

  (: verify that public resources are accessible :)
  let $response := xdmp:http-get(t:easy-url("/js/app.js"), $options-non-xml)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code))
  ),

  (: verify that a non-existent route returns 404 :)
  let $response := xdmp:http-get(t:easy-url("/not-real"), $options-non-xml)
  return
  (
    t:assert-equal(404, fn:data($response[1]/*:code))
  ),

  (: verify that a non-existent route returns 404 :)
  let $response := xdmp:http-get(t:easy-url("/not-real.xml"), $options-non-xml)
  return
  (
    t:assert-equal(404, fn:data($response[1]/*:code))
  ),

  (: verify that a non-existent route returns 404 :)
  let $response := xdmp:http-get(t:easy-url("/not-real/at-all"), $options-non-xml)
  return
  (
    t:assert-equal(404, fn:data($response[1]/*:code))
  ),

  let $response := xdmp:http-get(t:easy-url("/tester/update"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code)),
    t:assert-equal("XDMP-UPDATEFUNCTIONFROMQUERY", fn:string($response[2]//*:code))
  ),

  let $response := xdmp:http-head(t:easy-url("/tester/update"), $options)
  return
  (
    t:assert-equal(500, fn:data($response[1]/*:code))
    (: A HEAD request doesn't get the body, so we can't check the detailed message :)
  ),

  let $response := xdmp:http-delete(t:easy-url("/tester/delete?uri=/delete-me.xml"), $options-non-xml)
  return
    t:assert-equal(200, fn:data($response[1]/*:code)),

  let $response := xdmp:http-post(t:easy-url("/tester/update"), $options-non-xml)
  return
    t:assert-equal(200, fn:data($response[1]/*:code)),

  let $response := xdmp:http-put(t:easy-url("/tester/update2"), $options-non-xml)
  return
    t:assert-equal(200, fn:data($response[1]/*:code))
};

declare function t:test2()
{
  let $doc := fn:doc("/test-insert.xml")/*
  let $doc2 := fn:doc("/test-insert2.xml")/*
  let $doc3 := fn:doc("/delete-me.xml")
  return
  (
    t:assert-equal(<test/>, $doc),
    t:assert-equal(<test/>, $doc2),
    t:assert-not-exists($doc3)
  )
};

declare function t:site-index()
{
  let $options :=
    <options xmlns="xdmp:http">
      <format xmlns="xdmp:document-get">xml</format>
      <authentication method="digest">
        <username>{$c:USER}</username>
        <password>{$c:PASSWORD}</password>
      </authentication>
    </options>
  let $response := xdmp:http-get(t:easy-url("/"), $options)
  return
  (
    t:assert-equal(200, fn:data($response[1]/*:code)),
    t:assert-equal(1, fn:count($response[2]//*:html))
  )
};