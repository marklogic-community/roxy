(:
Copyright 2012-2015 MarkLogic Corporation

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

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/lib/view-helper.xqy";

declare namespace soap = "http://schemas.xmlsoap.org/soap/envelope/";

declare variable $header as item()* := vh:get("header");
declare variable $view as item()* := vh:get("view");
declare variable $error as item()* := vh:get("error");

xdmp:set-response-content-type("application/soap+xml"),
<soap:Envelope>
  <soap:Header>
  {
    $header
  }
  </soap:Header>
  <soap:Body>
  {
    if ($error) then
      $error
    else
      $view
  }
  </soap:Body>
</soap:Envelope>
