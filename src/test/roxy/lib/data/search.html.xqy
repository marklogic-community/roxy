xquery version "1.0-ml";

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/view-helper.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare variable $response := vh:get("response");

<div xmlns="http://www.w3.org/1999/xhtml">
  <p>Total results { fn:string($response/@total) } for "{fn:string($response/*:qtext)}"</p>
</div>