xquery version "1.0-ml";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

(: remove the test controller and views :)
test:remove-modules((
  "/app/views/layouts/different-layout.html.xqy",
  "/app/controllers/tester.xqy"
)),
test:remove-modules-directories((
  "/app/views/tester/"
)),

try
{
	xdmp:document-delete("/test-insert.xml")
}
catch($ex){()},

try
{
  xdmp:document-delete("/test-insert2.xml")
}
catch($ex){()}
