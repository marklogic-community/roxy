import module namespace test="http://marklogic.com/ps/test-helper" at "/test/test-helper.xqy";

declare namespace t="http://marklogic.com/ps/test";

test:assert-equal(<t:result type="success"/>, test:success())