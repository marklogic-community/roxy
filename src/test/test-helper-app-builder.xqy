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
module namespace helper = "http://marklogic.com/ps/test-helper-app-builder";

import module namespace config="http://marklogic.com/appservices/config" at "/roxy/lib/config.xqy";

(:  test-app-builder
 :
 :  Created by Preston McGowan on 2012-01-10.
 :  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
 :)

declare variable $logging-enabled := fn:false();

declare function helper:add-to-context($element-names, $element-values) {
    let $new-context := element context {
        $config:CONTEXT/node()
        ,
        for $name at $i in $element-names
        return element { $name } { $element-values[$i] }
    }
    return xdmp:set($config:CONTEXT, $new-context)
};

declare function helper:replace-in-context($element-name, $element-value) {
  let $new-context := element context {
    for $n in $config:CONTEXT/node()
    return
      if (fn:node-name($n) eq xs:QName($element-name)) then element {$element-name} {$element-value}
      else $n
  }
  return xdmp:set($config:CONTEXT, $new-context)
};

declare function helper:get-search-results() {
    $config:RESPONSE
};

declare function helper:get-search-result-total() {
    let $_ :=
        if ($logging-enabled) then
            xdmp:log(text{"get-search-result-total:", $config:CONTEXT/q, ":", $config:RESPONSE/fn:data(@total)})
        else ()
    return $config:RESPONSE/fn:data(@total)
};

declare function helper:get-page() {
    let $_ := xdmp:log(text{"get-page:"})
    let $_ := xdmp:log(xdmp:apply($config:page))
    return xdmp:apply($config:page)
};

declare function helper:get-content() {
    let $_ := xdmp:log(text{"get-content:"})
    let $_ := xdmp:log(xdmp:apply($config:content))
    return xdmp:apply($config:content)
};

declare function helper:get-toolbar() {
    xdmp:apply($config:toolbar)
};