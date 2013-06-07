xquery version "1.0-ml";
module namespace example = "http://marklogic.com/rest-api/transform/add-attr";

declare namespace roxy = "http://marklogic.com/roxy";

(: REST API transforms managed by Roxy must follow these conventions:

1. Their filenames must reflect the name of the transform.

For example, an XQuery transform named add-attr must be contained in a file named add-attr.xqy
and have a module namespace of "http://marklogic.com/rest-api/transform/add-attr".

2. Must declare the roxy namespace with the URI "http://marklogic.com/roxy".

declare namespace roxy = "http://marklogic.com/roxy";

3. Must annotate the transform function with the transform parameters:

%roxy:params("uri=xs:string", "priority=xs:int")

:)

declare
%roxy:params("uri=xs:string", "priority=xs:int")
function example:transform(
 $context as map:map,
 $params as map:map,
 $content as document-node()
) as document-node()
{
 if (fn:empty($content/*)) then $content
 else
 let $value := (map:get($params,"value"),"UNDEFINED")[1]
 let $name := (map:get($params, "name"), "transformed")[1]
 let $root := $content/*
 return document {
 $root/preceding-sibling::node(),
 element {fn:name($root)} {
attribute { fn:QName("", $name) } {$value},
 $root/@*,
 $root/node()
 },
 $root/following-sibling::node()
 }
};
