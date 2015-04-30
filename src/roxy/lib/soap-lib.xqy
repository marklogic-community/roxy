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

module namespace soap = "http://marklogic/roxy/soap";

declare namespace env = "http://schemas.xmlsoap.org/soap/envelope/";

declare namespace xsd="http://www.w3.org/2001/XMLSchema";

declare function soap:get-op-name($msg)
{
  fn:local-name($msg/env:Envelope/env:Body/element()[1])
};

declare function soap:get-param($msg, $param)
{
  soap:get-param($msg, $param, ())
};

declare function soap:get-param($msg, $param, $default)
{
  let $p-node := $msg/env:Envelope/env:Body/element()/element()[fn:local-name(.) = $param]
  return
    if (fn:exists($p-node) and fn:string($p-node) ne "") then
      xdmp:apply(xdmp:function($p-node/@xsi:type), $p-node)
    else
      $default
};
