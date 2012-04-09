xquery version "1.0-ml";

import module namespace test="http://marklogic.com/ps/test-helper" at "/test/test-helper.xqy";

import module namespace c = "http://marklogic.com/ns/test-config" at "/test/test-config.xqy";

import module namespace u = "http://marklogic.com/framework/util" at "/roxy/lib/util.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

test:assert-equal(fn:true(), u:module-file-exists("/test/suites/Framework Tests/util.xqy"))