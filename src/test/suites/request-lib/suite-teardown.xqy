xquery version "1.0-ml";

(: remove the test controller :)
if (xdmp:modules-database() ne 0) then
  xdmp:eval('
    xquery version "1.0-ml";
    xdmp:document-delete("/app/controllers/test-request.xqy")',
    (),
    <options xmlns="xdmp:eval">
      <database>{xdmp:modules-database()}</database>
    </options>)
else ()