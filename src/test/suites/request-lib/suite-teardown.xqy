xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

(: remove the test controller :)
test:remove-modules(("/app/controllers/test-request.xqy"))
