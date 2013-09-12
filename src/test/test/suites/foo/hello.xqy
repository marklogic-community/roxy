xquery version "1.0-ml";

module namespace htest="http://marklogic.com/roxy/test";

import module namespace test="http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

(: Your Test code goes here :)

declare function htest:hello-world() {
	test:assert-true(fn:false())
};

declare function htest:its-good-to-be-bad() {
	test:assert-true()
};
