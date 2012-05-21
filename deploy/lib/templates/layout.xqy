xquery version "1.0-ml";

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/lib/view-helper.xqy";

declare variable $view as item()* := vh:get("view");
declare variable $title as xs:string? := (vh:get('title'), "New Roxy Application")[1];

(: put your code here :)