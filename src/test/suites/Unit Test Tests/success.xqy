import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare namespace t="http://marklogic.com/roxy/test";

test:assert-equal(<t:result type="success"/>, test:success())