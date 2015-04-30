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

declare variable $view as item()* := vh:get("view");
declare variable $title as xs:string? := (vh:get('title'), "New Roxy Application")[1];

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>{$title}</title>
    <link href="/css/themes/ui-lightness/jquery-ui.css" type="text/css" rel="stylesheet"/>
    <link href="/css/app.css" type="text/css" rel="stylesheet"/>
    <script src="/js/lib/jquery-1.7.1.min.js" type='text/javascript'></script>
    <script src="/js/lib/jquery-ui-1.8.18.min.js" type='text/javascript'></script>
    <script src="/js/app.js" type='text/javascript'></script>
  </head>
  <body>
    <div class="index">
      <img src="/images/ml-logo.gif" style="float:right;"/>
      <div class="section">
        { $view }
      </div>
    </div>
  </body>
</html>