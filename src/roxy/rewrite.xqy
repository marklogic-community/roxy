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
import module namespace def = "http://marklogic.com/roxy/defaults" at "/roxy/config/defaults.xqy";
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

declare option xdmp:mapping "false";

req:rewrite(
  xdmp:get-request-url(),
  xdmp:get-request-path(),
  xdmp:get-request-method(),
  $config:ROXY-ROUTES)