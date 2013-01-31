xquery version "1.0-ml";
(:
Copyright 2012-2013 MarkLogic Corporation

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

module namespace c = "http://marklogic.com/roxy/controller/user";

(: The controller helper library provides methods
 : to control view and template rendering.
 :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper"
 at "/roxy/lib/controller-helper.xqy";

(: The request library provides awesome helper methods
 : to abstract xdmp:get-request-field.
 :)
import module namespace req = "http://marklogic.com/roxy/request" at
 "/roxy/lib/request.xqy";

declare option xdmp:mapping "false";

(:
 : Usage Notes:
 :
 : use the ch library to pass variables to the view
 :
 : use the request (req) library to get access to request parameters easily
 :
 :)
declare function c:profile() as item()*
{
  ch:set-value('title', 'User Profile'),
  ch:use-view((), "xml"),
  ch:use-layout('application', "html")
};

declare function c:login() as item()*
{
  ch:set-value('title', 'Login'),
  ch:set-value("username", req:get('username')),
  ch:set-value("password", req:get('password')),
  ch:set-value("redirect-to", '/'),
  ch:use-view((), "xml"),
  ch:use-layout('application', "html")
};

declare function c:logout() as item()*
{
  ch:set-value('title', 'Logout'),
  ch:set-value("redirect-to", '/'),
  ch:use-view((), "xml"),
  ch:use-layout((), "xml")
};
