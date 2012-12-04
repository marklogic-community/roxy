xquery version "1.0-ml";

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/lib/view-helper.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare variable $message as xs:string := vh:required("message");

<div id="message" xmlns="http://www.w3.org/1999/xhtml">{$message}</div>