xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";

import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

(: build-uri :)
test:assert-equal("base/suffix", u:build-uri("base", "suffix")),
test:assert-equal("base/suffix", u:build-uri("base", "/suffix")),
test:assert-equal("base/suffix", u:build-uri("base/", "suffix")),
test:assert-equal("base/suffix", u:build-uri("base/", "/suffix")),


(: string-pad :)

test:assert-equal("000", u:string-pad("0", 3)),

(: lead-zero :)
test:assert-equal("00001", u:lead-zero("1", 5)),
test:assert-equal("123", u:lead-zero("123", 3))