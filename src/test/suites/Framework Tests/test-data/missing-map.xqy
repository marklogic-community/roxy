xquery version "1.0-ml";

module namespace c = "http://marklogic.com/roxy/controller/missing-map";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/framework/request" at "/lib/request.xqy";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/lib/controller-helper.xqy";

import module namespace search = "http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare function c:main() as item()*
{
  "testing"
};