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

import module namespace uv = "http://www.marklogic.com/roxy/user-view"
  at "/app/views/helpers/user-lib.xqy";
import module namespace vh = "http://marklogic.com/roxy/view-helper"
 at "/roxy/lib/view-helper.xqy";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare variable $REDIRECT-TO as xs:string := vh:required("redirect-to");

if (xdmp:get-request-method() = 'POST') then (
  let $username as xs:string := vh:required("username")
  let $password as xs:string := vh:required("password")
  let $redirect-to as xs:string := vh:required("redirect-to")
  let $success := xdmp:login($username, $password)
  return xdmp:redirect-response($REDIRECT-TO))
else uv:login-form()

(: login.html.xqy :)
