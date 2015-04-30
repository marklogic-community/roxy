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

(: The private functions to support cpf.xqy :)
xquery version "1.0-ml";

import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";

declare variable $map as map:map external;

declare option xdmp:mapping "false";

declare private function local:clean-cpf()
{
  let $config := try { dom:configuration-get() } catch ($e) {}
  return
    if ($config) then
    (
      for $d in dom:domains()
      let $name as xs:string := $d/dom:domain-name
      return
        dom:remove($name),

      for $x as xs:string in p:pipelines( )/p:pipeline-name
      return
        p:remove($x)
    )
    else ()
};

declare private function local:get-cpf-files($dir as xs:string, $extension as xs:string) as xs:string*
{
  for $dir in xdmp:filesystem-directory($dir)//dir:entry
  return
  (
    $dir[dir:type="file"]/dir:pathname[fn:ends-with(., $extension)],
    for $d in $dir[dir:type="directory"]/dir:pathname
    return
      local:get-cpf-files($d, $extension)
  )
};

declare private function local:get-pipeline-files($dir as xs:string) as xs:string*
{
  for $entry in xdmp:filesystem-directory($dir)//dir:entry
  return
  (
    $entry[dir:type="file"]/dir:pathname[fn:ends-with(., ".xml")],
    local:get-pipeline-files($entry[dir:type="directory"]/dir:pathname)
  )
};

declare private function local:get-css-files($dir as xs:string) as xs:string*
{
  for $entry in xdmp:filesystem-directory($dir)//dir:entry
  let $css-files :=
    for $file as xs:string in $entry[dir:type="file"]/dir:pathname[fn:ends-with(., ".css")]
    let $css-name := fn:replace($file, fn:concat("^", $dir, "[\\/](.*)$"), "$1")
    return
      xdmp:load($file, $css-name)
  return
    for $d as xs:string in $entry[dir:type="directory"]/dir:pathname
    return
      local:get-css-files($d)
};

declare private function local:install-system-pipelines($names as xs:string*)
{
  local:get-css-files("Installer"),

  if ($names) then
    for $pipeline-uri in local:get-cpf-files("Installer", ".xml")
    let $pipeline := xdmp:document-get($pipeline-uri)/p:pipeline
    where $pipeline/p:pipeline-name = $names
    return
      p:insert($pipeline)
  else ()
};

declare private function local:install-cpf-pipelines(
  $pipeline-uris as xs:string*,
  $modules-database as xs:unsignedLong) as xs:unsignedLong*
{
  for $uri in $pipeline-uris
  let $doc :=
    let $map :=
      let $map := map:map()
      let $_ := (
        map:put($map, "function", "get-doc"),
        map:put($map, "uri", $uri))
      return
        $map
    return
      local:call-private-function($map, $modules-database)
  return
    p:insert($doc/*)
};

declare private function local:create-cpf-domain(
  $domain-name as xs:string,
  $description as xs:string,
  $domain-scope as element(dom:domain-scope),
  $context as element(dom:evaluation-context),
  $pipeline-ids as xs:unsignedLong*,
  $permissions as element(sec:permission)*) as xs:unsignedLong
{
  let $domain-id := try { fn:data(dom:get($domain-name)/dom:domain-id) } catch ($e) { () }
  return
    (: update the existing domain :)
    if ($domain-id) then
      let $_ :=
      (
        dom:set-description($domain-name, $description),
        dom:set-domain-scope($domain-name, $domain-scope),
        dom:set-evaluation-context($domain-name, $context),
        dom:set-pipelines($domain-name, $pipeline-ids),
        dom:set-permissions($domain-name, $permissions)
      )
      return
        $domain-id
    (: create a new domain :)
    else
      let $domain-id := dom:create($domain-name, $description, $domain-scope, $context, $pipeline-ids, $permissions)
      return
        $domain-id
};

declare private function local:create-cpf-configuration(
  $restart-user as xs:string,
  $evaluation-context as element(dom:evaluation-context),
  $default-domain as xs:unsignedLong,
  $permissions as element(sec:permission)*)
{
  let $config :=
    let $map :=
      let $map := map:map()
      let $_ := map:put($map, "function", "configuration-get")
      return
        $map
    return
      local:call-private-function($map, ())
  return
    if ($config) then
      let $config := dom:configuration-set-restart-user($restart-user)
      let $config := dom:configuration-set-evaluation-context($evaluation-context)
      let $config := dom:configuration-set-default-domain($default-domain)
      let $config := dom:configuration-set-permissions($permissions)
      let $config := dom:configuration-set-conversion-enabled(fn:false())
      return
        "Updated configuration"
    else
      let $config :=
        let $map :=
          let $map := map:map()
          let $_ := (
            map:put($map, "function", "configuration-create"),
            map:put($map, "restart-user", $restart-user),
            map:put($map, "evaluation-context", $evaluation-context),
            map:put($map, "default-domain", $default-domain),
            map:put($map, "permissions", $permissions))
          return
            $map
        return
          local:call-private-function($map, ())
      let $option :=
        let $map :=
          let $map := map:map()
          let $_ := (
            map:put($map, "function", "enable-conversion"),
            map:put($map, "enable", fn:false()))
          return
            $map
        return
          local:call-private-function($map, ())
      return
        "Created configuration"
};

declare private function local:evaluation-context(
  $database as xs:unsignedLong,
  $root as xs:string) as element(dom:evaluation-context)
{
  dom:evaluation-context($database, $root)
};

declare private function local:configuration-get() as element(dom:configuration)?
{
  try
  {
    dom:configuration-get()
  }
  catch($e) {}
};

declare private function local:configuration-create(
  $restart-user as xs:string,
  $evaluation-context as element(dom:evaluation-context),
  $default-domain as xs:unsignedLong,
  $permissions as element(sec:permission)*) as xs:unsignedLong
{
  dom:configuration-create($restart-user, $evaluation-context, $default-domain, $permissions)
};

declare private function local:enable-conversion($enable as xs:boolean)
{
  dom:configuration-set-conversion-enabled($enable)
};

declare private function local:call-private-function(
  $map as map:map,
  $database-id as xs:unsignedLong?)
{
  xdmp:invoke(
    "/roxy/lib/cpf-private.xqy",
    (xs:QName("map"), $map),
    if ($database-id) then
      <options xmlns="xdmp:eval">
        <database>{$database-id}</database>
      </options>
    else ())
};

declare private function local:get-doc($uri as xs:string)
{
  fn:doc($uri)
};

let $function := map:get($map, "function")
return
  if ($function eq "clean-cpf") then
    local:clean-cpf()
  else if ($function eq "install-system-pipelines") then
    local:install-system-pipelines(map:get($map, "names"))
  else if ($function eq "install-cpf-pipelines") then
    local:install-cpf-pipelines(
      map:get($map, "pipeline-uris"),
      map:get($map, "modules-database"))
  else if ($function eq "create-cpf-domain") then
    local:create-cpf-domain(
      map:get($map, "domain-name"),
      map:get($map, "description"),
      map:get($map, "domain-scope"),
      map:get($map, "context"),
      map:get($map, "pipeline-ids"),
      map:get($map, "permissions"))
  else if ($function eq "create-cpf-configuration") then
    local:create-cpf-configuration(
      map:get($map, "restart-user"),
      map:get($map, "evaluation-context"),
      map:get($map, "default-domain"),
      map:get($map, "permissions"))
  else if ($function eq "evaluation-context") then
    local:evaluation-context(
      map:get($map, "database"),
      map:get($map, "root"))
  else if ($function eq "configuration-get") then
    local:configuration-get()
  else if ($function eq "configuration-create") then
    local:configuration-create(
      map:get($map, "restart-user"),
      map:get($map, "evaluation-context"),
      map:get($map, "default-domain"),
      map:get($map, "permissions"))
  else if ($function eq "enable-conversion") then
    local:enable-conversion(map:get($map, "enable"))
  else if ($function eq "get-doc") then
    local:get-doc(map:get($map, "uri"))
  else ()