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

import module namespace config = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

let $url := xdmp:get-request-url()
let $path := xdmp:get-request-path()
let $verb := xdmp:get-request-method()
let $options :=
  <rest:options>
    { $config:ROUTES/rest:request }
    <rest:request uri="^/test/(js|img|css)/(.*)" />
    <rest:request uri="^/test/(.*)" endpoint="/test/default.xqy">
      <rest:uri-param name="func" default="main">$1</rest:uri-param>
    </rest:request>
    <rest:request uri="^/test$" redirect="/test/" />
    <rest:request uri="^/(css|js|images)/(.*)" endpoint="/public/$1/$2"/>
    <rest:request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/query-router.xqy">
      <rest:uri-param name="controller" default="{$config:DEFAULT-CONTROLLER}">$1</rest:uri-param>
      <rest:uri-param name="func" default="main">$2</rest:uri-param>
      <rest:uri-param name="format">$3</rest:uri-param>
      <rest:http method="GET"/>
    </rest:request>
    <rest:request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/update-router.xqy">
      <rest:uri-param name="controller" default="{$config:DEFAULT-CONTROLLER}">$1</rest:uri-param>
      <rest:uri-param name="func" default="main">$2</rest:uri-param>
      <rest:uri-param name="format">$3</rest:uri-param>
      <rest:http method="POST"/>
      <rest:http method="PUT"/>
    </rest:request>
    <rest:request uri="^.+$"/>
  </rest:options>
return
  req:rewrite($url, $path, $verb, $options)