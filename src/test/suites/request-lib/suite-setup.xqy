xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

(: create a test controller and views :)
test:load-test-file("test-request.xqy", xdmp:modules-database(), fn:concat(xdmp:modules-root(), "app/controllers/test-request.xqy"))