xquery version "1.0-ml";
module namespace trns = "http://marklogic.com/rest-api/transform/sample";

declare namespace roxy = "http://marklogic.com/roxy";

(: REST API transforms managed by Roxy must follow these conventions:

1. Their filenames must reflect the name of the transform.

For example, an XQuery transform named add-attr must be contained in a file named add-attr.xqy
and have a module namespace of "http://marklogic.com/rest-api/transform/add-attr".

2. Must declare the roxy namespace with the URI "http://marklogic.com/roxy".

declare namespace roxy = "http://marklogic.com/roxy";

3. Must annotate the transform function with the transform parameters:

%roxy:params("uri=xs:string", "priority=xs:int")

These can be retrieved with map:get($params, "uri"), for example.

:)

declare
%roxy:params()
function trns:transform(
  $context as map:map,
  $params as map:map,
  $content as document-node()
) as document-node()
{
  $content
};
