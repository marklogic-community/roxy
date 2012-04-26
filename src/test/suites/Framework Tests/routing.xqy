xquery version "1.0-ml";

(: Create a target for the DELETE test :)

xdmp:document-insert("/delete-me.xml", <or-query><to-be/><not-to-be/></or-query>)

;

xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

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


(: Verify that /tester will call tester:main and return the html view :)
let $response := xdmp:http-get(test:easy-url("/tester"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("main", fn:string($response[2]//html:title)),
  test:assert-equal("test message: main", fn:string($response[2]//html:div[@id="message"]))
),

(: Verify that the .html will return the html view :)
let $response := xdmp:http-get(test:easy-url("/tester.html"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("main", fn:string($response[2]//html:title)),
  test:assert-equal("test message: main", fn:string($response[2]//html:div[@id="message"]))
),

(: Verify that the .xml will return the xml view :)
let $response := xdmp:http-get(test:easy-url("/tester.xml"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("test message: main", fn:string($response[2]/xml))
),

(: JSON view is not defined. Should throw a 500 error with handy error message :)
let $response := xdmp:http-get(test:easy-url("/tester.json"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Missing the view:tester/main.json"))
),

(: verify that a handy error message is displayed when a layout is missing. :)
let $response := xdmp:http-get(test:easy-url("/tester/missing-layout"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Layout:i-dont-exist"))
),

(: verify that a handy error message is displayed when a view is missing. :)
let $response := xdmp:http-get(test:easy-url("/tester/missing-view"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "Missing the view:tester/missing-view.html"))
),

(: verify that turning off the layout works :)
let $response := xdmp:http-get(test:easy-url("/tester/no-layout"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-not-exists($response[2]//html:html),
  test:assert-equal("test message: no-layout", fn:string($response[2]/html:div[@id="message"]))
),

(: verify that turning off the view works :)
let $response := xdmp:http-get(test:easy-url("/tester/no-view"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-not-exists($response[2]//html:div[@class="content"]/*),
  test:assert-equal("test message: no-view", fn:string($response[2]//html:div[@class="content"]))
),

(: verify that turning off the view and layout works :)
let $response := xdmp:http-get(test:easy-url("/tester/no-view-or-layout"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("test message: no-view-or-layout", fn:string($response[2]/x))
),

(: verify that specifying a different view works :)
let $response := xdmp:http-get(test:easy-url("/tester/different-view"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("different-view", fn:string($response[2]//html:title)),
  test:assert-equal("test message: different-view", fn:string($response[2]//html:div[@id="message" and @class="main"]))
),

(: verify that specifying a different layout works :)
let $response := xdmp:http-get(test:easy-url("/tester/different-layout"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal(1, fn:count($response[2]//html:body[@class="different-layout"])),
  test:assert-equal("test message: different-layout", fn:string($response[2]//html:div[@id="message"]))
),

(: verify that specifying a different view for only xml works - first get html :)
let $response := xdmp:http-get(test:easy-url("/tester/different-view-xml-only"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("different-view", fn:string($response[2]//html:title)),
  test:assert-equal("test message: different-view", fn:string($response[2]//html:div[@id="message"]))
),

(: verify that specifying a different view for only xml works - now get xml :)
let $response := xdmp:http-get(test:easy-url("/tester/different-view-xml-only.xml"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-equal("test message: different-view", fn:string($response[2]/xml))
),

(: verify that returning the input from the view doesn't break anything :)
let $response := xdmp:http-get(test:easy-url("/tester/view-that-returns-the-input"), $options)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code)),
  test:assert-not-exists($response[2]//html:div[@class="content"]/*),
  test:assert-equal("view-that-returns-the-input", fn:string($response[2]//html:div[@class="content"]))
),

(: verify that a missing variable returns a handy error message :)
let $response := xdmp:http-get(test:easy-url("/tester/missing-variable"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains(fn:string($response[2]//html:div[@class="error-message"]), "is expecting the parameter message"))
),

(: verify that a bad import propagates the correct error :)
let $response := xdmp:http-get(test:easy-url("/tester/layout-with-bad-import"), $options-non-xml)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains($response[2], "SVC-FILOPN") or fn:contains($response[2], "XDMP-MODNOTFOUND"))
),

(: verify that a bad import propagates the correct error :)
let $response := xdmp:http-get(test:easy-url("/tester/view-with-bad-import"), $options-non-xml)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-true(fn:contains($response[2], "SVC-FILOPN") or fn:contains($response[2], "XDMP-MODNOTFOUND"))
),


(: verify that public resources are accessible :)
let $response := xdmp:http-get(test:easy-url("/css/app.less"), $options-non-xml)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code))
),

(: verify that public resources are accessible :)
let $response := xdmp:http-get(test:easy-url("/images/ml-logo.gif"), $options-non-xml)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code))
),

(: verify that public resources are accessible :)
let $response := xdmp:http-get(test:easy-url("/js/app.js"), $options-non-xml)
return
(
  test:assert-equal(200, fn:data($response[1]/*:code))
),

(: verify that a non-existent route returns 404 :)
let $response := xdmp:http-get(test:easy-url("/not-real"), $options-non-xml)
return
(
  test:assert-equal(404, fn:data($response[1]/*:code))
),

(: verify that a non-existent route returns 404 :)
let $response := xdmp:http-get(test:easy-url("/not-real.xml"), $options-non-xml)
return
(
  test:assert-equal(404, fn:data($response[1]/*:code))
),

(: verify that a non-existent route returns 404 :)
let $response := xdmp:http-get(test:easy-url("/not-real/at-all"), $options-non-xml)
return
(
  test:assert-equal(404, fn:data($response[1]/*:code))
),

let $response := xdmp:http-get(test:easy-url("/tester/update"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code)),
  test:assert-equal("XDMP-UPDATEFUNCTIONFROMQUERY", fn:string($response[2]//*:code))
),

let $response := xdmp:http-head(test:easy-url("/tester/update"), $options)
return
(
  test:assert-equal(500, fn:data($response[1]/*:code))
  (: A HEAD request doesn't get the body, so we can't check the detailed message :)
),

let $response := xdmp:http-delete(test:easy-url("/tester/delete?uri=/delete-me.xml"), $options-non-xml)
return 
  test:assert-equal(200, fn:data($response[1]/*:code)),

let $response := xdmp:http-post(test:easy-url("/tester/update"), $options-non-xml)
return
  test:assert-equal(200, fn:data($response[1]/*:code)),

let $response := xdmp:http-put(test:easy-url("/tester/update2"), $options-non-xml)
return
  test:assert-equal(200, fn:data($response[1]/*:code))

;

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
let $doc := fn:doc("/test-insert.xml")/*
let $doc2 := fn:doc("/test-insert2.xml")/*
let $doc3 := fn:doc("/delete-me.xml")
return
(
  test:assert-equal(<test/>, $doc),
  test:assert-equal(<test/>, $doc2),
  test:assert-not-exists($doc3)
)