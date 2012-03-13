xquery version "1.0-ml";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/lib/controller-helper.xqy";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/framework/request" at "/lib/request.xqy";

declare namespace c = "http://marklogic.com/roxy/controller/#controller-name";

declare variable $function-QName as xs:QName external;

declare option xdmp:mapping "false";

(:
 : Usage Notes:
 :
 : use the ch library to pass variables to the view
 :
 : use the request (req) library to get access to request parameters easily
 :
 :)
declare function c:#function-name() as item()*
{
  ch:add-value("message", "This is a test message."),
  ch:add-value("title", "This is a test page title"),
  ch:use-view((), "xml"),
  ch:use-layout((), "xml")
};

xdmp:apply(xdmp:function($function-QName))