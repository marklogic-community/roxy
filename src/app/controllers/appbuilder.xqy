(:
Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
xquery version "1.0-ml";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/lib/controller-helper.xqy";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/framework/request" at "/lib/request.xqy";

import module namespace s = "http://marklogic.com/ns/models/search" at "/app/models/search-lib.xqy";

declare namespace c = "http://marklogic.com/roxy/controller/appbuilder";

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
declare function c:main() as item()*
{
  let $q as xs:string := req:get("q", "", "type=xs:string")
  let $page := req:get("page", 1, "type=xs:int")
  return
  (
    ch:add-value("response", s:search($q, $page)),
    ch:add-value("q", $q),
    ch:add-value("page", $page)
  ),
  ch:use-view((), "xml"),
  ch:use-layout((), "xml")
};

(: Apply the passed-in function :)
xdmp:apply(xdmp:function($function-QName))
