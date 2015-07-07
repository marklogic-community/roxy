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

import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";
import module namespace router = "http://marklogic.com/roxy/router" at "/roxy/router.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare variable $error:errors as node()* external;
declare variable $ex := ($error:errors)[1];

declare variable $view as xs:string? := fn:replace(($ex//error:variable[error:name = "view"]/error:value)[1], '"', '');
declare variable $layout as xs:string? := fn:replace(($ex//error:variable[error:name = "layout"]/error:value)[1], '"', '');
declare variable $format as xs:string? := fn:replace(($ex//error:variable[error:name = "format"]/error:value)[1], '"', '');
declare variable $view-path as xs:string := fn:concat("/app/views/", $view, ".", $format, ".xqy");
declare variable $layout-path := fn:concat("/app/views/layouts/", $layout, ".", $format, ".xqy");
declare variable $MESSAGES :=
  <messages>
    <message code="MISSING-VIEW" title="Missing the view: {$view}">
      <div class="error-message" xmlns="http://www.w3.org/1999/xhtml">
        Missing the view:<span class="highlight">{$view}.{$format}</span> at <span class="highlight">{$view-path}</span>
      </div>
    </message>
    <message code="MISSING-PARAM" title="Missing the parameter: {fn:string($ex/error:code)}">
      <div class="error-message" xmlns="http://www.w3.org/1999/xhtml">
        The file<span class="highlight">{$view-path}</span> is expecting the parameter <span class="missing-param">{fn:string($ex/error:code)}</span> to be declared in <span class="label">File:</span> <span class="highlight">/controllers/{fn:tokenize($view, "/")[1]}.xqy</span> function: <span class="missing-param">{fn:tokenize($view, "/")[2]}</span>
        <p class="label">Add the following code:</p>
        <div class="code">
          <pre class="unimportant">
          xquery version "1.0-ml";

          module namespace c = "http://marklogic.com/roxy/controller/{fn:data($ex/error:data/error:datum[3])}";

          import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";
          import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

          declare variable $map as map:map external;

          declare function c:{fn:tokenize($view, "/")[2]}()
          {{
          ...
          </pre>
          <pre class="important">
            map:put($map, "{fn:string($ex/error:code)}", "some-value")
          </pre>
          <pre class="unimportant">
          }};
          </pre>
        </div>
      </div>
    </message>
    <message code="MISSING-CONTROLLER-PARAM" title="Missing the parameter: {fn:data($ex/error:data/error:datum[1])}">
      <div class="error-message" xmlns="http://www.w3.org/1999/xhtml">
        The file<span class="highlight">{fn:data($ex/error:data/error:datum[2])}</span> is expecting the HTTP request parameter <span class="missing-param">{fn:data($ex/error:data/error:datum[1])}</span>
      </div>
    </message>
    <message code="MISSING-LAYOUT" title="Missing the layout: {$layout}">
      <div class="error-message" xmlns="http://www.w3.org/1999/xhtml">
      Missing the Layout:<span class="highlight">{$layout}</span> at<span class="highlight">{$layout-path}</span>
      </div>
    </message>
    <message code="MISSING-MAP">
      <div class="error-message" xmlns="http://www.w3.org/1999/xhtml">
        <p class="label">Add the following code:</p>
        <div class="code" xmlns="http://www.w3.org/1999/xhtml">
          <pre class="unimportant">
          xquery version "1.0-ml";

          module namespace c = "http://marklogic.com/roxy/controller/your-controller";

          import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";
          import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";
          </pre>
          <pre class="important">
          declare variable $map as map:map external;
          </pre>

          <pre class="unimportant">
          declare function c:your-function() {{
          ...
          }}
          </pre>
        </div>
      </div>
    </message>
  </messages>;
(:xdmp:set-response-content-type("text/plain"),
xdmp:get-response-code(),
$error:errors
:)

declare function local:four-o-four()
{
  xdmp:set-response-code(404, "Not Found"),
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>404 Not Found</title>
      <meta name="robots" content="noindex,nofollow"/>
    </head>
    <body>
      <h1>404 Not Found</h1>
    </body>
  </html>
};

declare function local:error($title as xs:string?, $heading, $msg)
{
  xdmp:set-response-code(500, 'Internal Server Error'),
  xdmp:set-response-content-type("text/html"),
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>{($title, "Exception Caught")[1]}</title>
      <meta name="robots" content="noindex,nofollow"/>
      <link rel="stylesheet" href="/css/error.css"/>
    </head>
    <body>
      <div class="error">
        <h1>{$heading}</h1>
        <p>{$msg}</p>
        <h2>Parameters</h2>
        <ul class="parameters">
        {
          for $key in xdmp:get-request-field-names()
          return
            <li><span class="param-name">{$key}</span> => {xdmp:get-request-field($key)}</li>
        }
        </ul>
      </div>
    </body>
  </html>
};

if (fn:starts-with($ex/error:code, "REST")) then
  xdmp:invoke(
    "/MarkLogic/rest-api/error-handler.xqy",
    (xs:QName("error:errors"), $error:errors)
  )
else if (($ex/error:code = "XDMP-UNDFUN" and $ex/error:data/error:datum = fn:concat($router:func, "()")) or
    ($ex/error:code = ("SVC-FILOPN", "XDMP-MODNOTFOUND") and $ex/error:data/error:datum/fn:ends-with(., $router:controller-path))) then
  local:four-o-four()
else if (($ex/error:name, $ex/error:code) = ("XDMP-UNDFUN") and fn:starts-with($ex/error:data/error:datum, "c:")) then
  local:four-o-four()
else if ($ex/error:name = $MESSAGES/message/@code) then
  local:error($MESSAGES/message[@code = $ex/error:name]/@title, fn:string($ex/error:message), $MESSAGES/message[@code = $ex/error:name]/node())
else if ($ex/error:name = "four-o-four" or 404 = xdmp:get-response-code()[1]) then
  local:four-o-four()
else if ($ex/error:code = "HTTP-ERROR") then
(
  xdmp:set-response-code(xs:int($ex/error:data/error:datum[1]), $ex/error:data/error:datum[2]),
  $ex/error:data/error:datum[3]/fn:data()
)
else
  (
    xdmp:set-response-content-type("text/plain"),
    $ex
  )
