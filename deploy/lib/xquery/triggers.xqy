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
  let $desc as xs:string? := $trgr/trgr:description
  let $event := triggers:get-event($trgr)
  let $module :=
    (: Convert from database name to id :)
    trgr:trigger-module(
      xdmp:database($trgr/trgr:module/trgr:database/fn:string()),
      $trgr/trgr:module/trgr:root,
      $trgr/trgr:module/trgr:path
    )
  let $enabled as xs:boolean := $trgr/trgr:enabled
  let $permissions as element()* :=
    triggers:resolve-permissions($trgr/trgr:permissions/sec:permission)
  let $recursive as xs:boolean := ($trgr/trgr:recursive, fn:true())[1]
  let $priority as xs:string := ($trgr/trgr:task-priority, "normal")[1]
  return
    if (fn:exists(/trgr:trigger/trgr:trigger-name[. = $name])) then
      (: trigger already exists. update it :)
      (
        if ($desc) then trgr:trigger-set-description($name, $desc) else (),
        trgr:trigger-set-event($name, $event),
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
        $event,
        $module,
        $enabled,
        $permissions,
        $recursive,
        $priority
      )
};

declare function triggers:resolve-permissions($perms as element(sec:permission)*)
  as element()*
{
  let $permissions :=
    for $perm in $perms
    return
      xdmp:permission(xdmp:role($perm/sec:role-name/fn:string()), $perm/sec:capability/fn:string())
  return
    if ($permissions) then
      $permissions
    else
      xdmp:default-permissions()
};

declare function triggers:get-event($trgr as element(trgr:trigger))
  as element()
{
  let $data-event := $trgr/trgr:data-event
  let $db-online-event :=
    if ($trgr/trgr:database-online-event) then
      <trgr:database-online-event>
        <trgr:user>{xdmp:user($trgr/trgr:database-online-event/trgr:user-name)}</trgr:user>
      </trgr:database-online-event>
    else ()
  return
    if (fn:exists($data-event)) then
      $data-event
    else if (fn:exists($db-online-event)) then
      $db-online-event
    else
      fn:error(xs:QName("EVENT-REQUIRED"), "A trigger must have a data-event or database-online-event")
};

declare function triggers:clean-triggers()
{
  for $trigger in /trgr:trigger
  return
    xdmp:document-delete(fn:base-uri($trigger))
};
