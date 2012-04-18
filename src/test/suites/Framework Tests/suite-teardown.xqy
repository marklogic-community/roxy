xquery version "1.0-ml";

(: remove the test controller and views :)
if (xdmp:modules-database() ne 0) then
  xdmp:eval('
    xquery version "1.0-ml";
    xdmp:directory-delete("/app/views/tester/"),
    xdmp:document-delete("/app/views/layouts/different-layout.html.xqy"),
    xdmp:document-delete("/app/controllers/tester.xqy")',
    (),
    <options xmlns="xdmp:eval">
      <database>{xdmp:modules-database()}</database>
    </options>)
else (),

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