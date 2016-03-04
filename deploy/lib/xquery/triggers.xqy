(:
Copyright 2016 MarkLogic Corporation

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

import module namespace trgr="http://marklogic.com/xdmp/triggers" at "/MarkLogic/triggers.xqy";

declare namespace triggers = "http://marklogic.com/roxy/triggers";

declare option xdmp:mapping "false";

(:
 : Loads a pipeline from a configuration xml
 :
 :@param $config - the configuration xml
 :
:)
declare function triggers:load-from-config($config as element(trgr:triggers))
{
  let $triggers-db := xdmp:database()
  for $trgr in $config/trgr:trigger
  let $name := $trgr/trgr:name
  let $desc as xs:string := $trgr/trgr:description
  let $data-event := $trgr/trgr:data-event
  let $module :=
    <trgr:module>
      <trgr:database>{xdmp:database($trgr/trgr:module/trgr:database/fn:string())}</trgr:database>
      {
        $trgr/trgr:module/* except $trgr/trgr:module/trgr:database
      }
    </trgr:module>
  let $enabled as xs:boolean := $trgr/trgr:enabled
  let $permissions as element()* :=
    (
      triggers:resolve-permissions($trgr/trgr:permissions/sec:permission),
      xdmp:default-permissions()
    )[1]
  let $recursive as xs:boolean := ($trgr/trgr:recursive, fn:true())[1]
  let $priority as xs:string? := $trgr/trgr:task-priority
  let $_ :=
    if (fn:empty($priority) or $priority = ("normal", "higher")) then ()
    else
      fn:error(xs:QName("PRIORITY-VALUE"), 'Task priority must be "normal" or "higher".')
  return
    if (fn:exists(/trgr:trigger/trgr:trigger-name[. = $name])) then
      (: trigger already exists. update it :)
      (
        trgr:trigger-set-description($name, $desc),
        trgr:trigger-set-event($name, $data-event),
        trgr:trigger-set-module($name, $module),
        if ($enabled) then trgr:trigger-enable($name)
        else trgr:trigger-disable($name),
        trgr:trigger-set-permissions($name, $permissions),
        trgr:trigger-set-recursive($name, $recursive),
        trgr:trigger-set-task-priority($name, $priority)
      )
    else
      (: new trigger. create it. :)
      trgr:create-trigger(
        $name, $desc,
        $data-event,
        $module,
        $enabled,
        $permissions,
        $recursive,
        ($priority, "normal")[1]
      )
};

declare function triggers:resolve-permissions($perms as element(sec:permission)*)
{
  for $perm in $perms
  return
    <sec:permission>
      {$perm/sec:capability}
      <sec:role-id>{xdmp:role($perm/sec:role-name)}</sec:role-id>
    </sec:permission>
};
