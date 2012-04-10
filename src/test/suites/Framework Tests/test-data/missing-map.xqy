xquery version "1.0-ml";

module namespace c = "http://marklogic.com/roxy/controller/missing-map";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";

declare option xdmp:mapping "false";

declare function c:main() as item()*
{
  "testing"
};