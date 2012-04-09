xquery version "1.0-ml";

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/lib/view-helper.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

<div id="message" class="main" xmlns="http://www.w3.org/1999/xhtml">{vh:get("message")}</div>