(: setup :)

xquery version "1.0-ml";

xdmp:document-insert("/test2.xml",
  <doc>
    <meta>
      <tags/>
    </meta>
  </doc>)

;

(: test :)

xquery version "1.0-ml";

xdmp:node-insert-child(
  fn:doc('/test2.xml')/doc/meta/tags,
  <tag>tag1</tag>
)

;

(: verify :)

xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

try {
  test:assert-exists(fn:doc("/test2.xml")/doc/meta/tags/tag[./text() = "tag1"])
} catch ($e) {
  if (fn:matches($e/error:name, "ASSERT-.*-FAILED")) then
    xdmp:rethrow()
  else
    xdmp:log("tag:add() verification threw an exception: " || xdmp:quote($e))
}

;

(: teardown :)
xdmp:document-delete("/test2.xml")
