xquery version "1.0-ml";

try {
  xdmp:node-insert-child(
    fn:doc('/test1.xml')/doc/meta/tags,
    <tag>tag1</tag>
  )
} catch ($e) {
  xdmp:log("tag:add() threw an exception: " || xdmp:quote($e))
}

;

xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

test:assert-exists(fn:doc("/test1.xml")/doc/meta/tags/tag[./text() = "tag1"])
