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

declare namespace cpf = "http://marklogic.com/roxy/cpf";

import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";

declare option xdmp:mapping "false";

(:
 : Loads a pipeline from a configuration xml
 :
 :@param $config - the configuration xml
 :
 : Sample Configuratione file:

<config xmlns="http://marklogic.com/roxy/cpf">
  <domains>
    <domain>
      <name>My Test Domain</name>
      <description>This domain is awesome!!!</description>
      <pipelines>
        <pipeline>/locaton/to/your/pipeline/in/a/modules/database.xml</pipeline>
      </pipelines>
      <system-pipelines>
        <!-- names of system pipelines -->
        <system-pipeline>Status Change Handling</system-pipeline>
      </system-pipelines>
      <scope>
        <type>directory</type>
        <uri>/</uri>
        <depth>infinity</depth>
      </scope>
<!--
      <scope>
        <type>collection</type>
        <uri>MyCollection</uri>
        <depth/>
      </scope>
      <scope>
        <type>document</type>
        <uri>/stuff.xml</uri>
        <depth/>
      </scope>
-->
      <context>
        <modules-database>your-modules-database-name</modules-database>
        <root>/</root>
      </context>
      <restart-user>your-restart-user-name</restart-user>
      <permissions>
  			<permission>
  				<capability>read</capability>
  				<role-name>admin</role-name>
  			</permission>
      </permissions>
    </domain>
  </domains>
</config>
:)
declare function cpf:load-from-config($config as element(cpf:config))
{
  for $domain in $config/cpf:domains/cpf:domain
  let $pipeline-ids :=
    (
      cpf:install-system-pipelines($domain/cpf:system-pipelines/cpf:system-pipeline),
      cpf:install-cpf-pipelines($domain/cpf:pipelines/cpf:pipeline, xdmp:database($domain/cpf:context/cpf:modules-database))
    )
  let $context := cpf:evaluation-context(xdmp:database($domain/cpf:context/cpf:modules-database), $domain/cpf:context/cpf:root)
  let $permissions :=
    <permissions>
    {
    for $permission in $domain/cpf:permissions/cpf:permission
    return
      xdmp:permission($permission/cpf:role-name, $permission/cpf:capability)
    }
    </permissions>
  let $domain-id :=
    cpf:create-cpf-domain(
      $domain/cpf:name,
      $domain/cpf:description,
      cpf:domain-scope($domain/cpf:scope/cpf:type, $domain/cpf:scope/cpf:uri, $domain/cpf:scope/cpf:depth),
      $context,
      $pipeline-ids,
      $permissions)
  return
    cpf:create-cpf-configuration(
      $domain/cpf:restart-user,
      $context,
      $domain-id,
      $permissions)
};

declare private function cpf:get-cpf-files($dir as xs:string, $extension as xs:string) as xs:string*
{
  for $dir in xdmp:filesystem-directory($dir)//dir:entry
  return
  (
    $dir[dir:type="file"]/dir:pathname[fn:ends-with(., $extension)],
    for $d in $dir[dir:type="directory"]/dir:pathname
    return
      cpf:get-cpf-files($d, $extension)
  )
};

(:
 : Removes all the cpf configuration for the current db
 :)
declare function cpf:clean-cpf()
{
  let $config := try { cpf:configuration-get() } catch ($e) {}
  return
    if ($config) then
    (
      xdmp:eval(
        'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
         import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
         for $d in dom:domains()
         let $name as xs:string := $d/dom:domain-name
         return
           dom:remove($name),

         for $x as xs:string in p:pipelines( )/p:pipeline-name
         return
           p:remove($x)',
        (),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
        </options>
      )
    )
    else ()
};

(:
 : Installs System pipeline xml files matching the given located names
 :
 : @param $names - the names of the system pipelines
 : @param $modules-database - the id of the modules database where the pipeline xml files are located
 : @return - the ids of the newly created pipelines
 :)
declare function cpf:install-system-pipelines($names as xs:string*) as xs:unsignedLong*
{
  if ($names) then
    for $pipeline-uri in cpf:get-cpf-files("Installer", ".xml")
    let $pipeline := xdmp:document-get($pipeline-uri)/p:pipeline
    where $pipeline/p:pipeline-name = $names
    return
      xdmp:eval(
        'import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
         declare variable $pipeline external;
         p:insert($pipeline)',
        (xs:QName("pipeline"), $pipeline),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
        </options>
      )
  else ()
};

(:
 : Installs the pipeline xml files located at the supplied uris in the supplied modules db
 :
 : @param $pipeline-uris - one or more uris to pipeline xml files to install
 : @param $modules-database - the id of the modules database where the pipeline xml files are located
 : @return - the ids of the newly created pipelines
 :)
declare function cpf:install-cpf-pipelines(
  $pipeline-uris as xs:string*,
  $modules-database as xs:unsignedLong) as xs:unsignedLong*
{
  for $uri in $pipeline-uris
  let $doc := 
    xdmp:eval(
      'declare variable $uri external;
       fn:doc($uri)',
      (xs:QName("uri"), $uri),
      <options xmlns="xdmp:eval">
        <database>{$modules-database}</database>
      </options>
    )
  return
    xdmp:eval(
      'import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
       declare variable $doc external;
       p:insert($doc/*)',
      (xs:QName("doc"), $doc),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
      </options>
    )
};

(:
 : Creates a cpf domain. If the domain already exists it is updated.
 :
 : @param $domain-name - the name of the domain to create
 : @param $description - the description of the domain
 : @param $domain-scope - The scope of the domain. Create using cpf:domain-scope
 : @param $context - The evaluation context for processing actions. Create using cpf:evaluation-context
 : @param $pipeline-names - The names of the pipelines to bind to this domain.
 : @param $permissions - The permissions for this domain
 : @return - the id of the newly created/updated domain
 :)
declare function cpf:create-cpf-domain(
  $domain-name as xs:string,
  $description as xs:string,
  $domain-scope as element(dom:domain-scope),
  $context as element(dom:evaluation-context),
  $pipeline-ids as xs:unsignedLong*,
  $permissions as element(permissions)) as xs:unsignedLong
{
  let $domain-id := 
    xdmp:eval(
      'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
       declare variable $domain-name external;
       try { fn:data(dom:get($domain-name)/dom:domain-id) } catch ($e) { () }',
      (xs:QName("domain-name"), $domain-name),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
      </options>)
  return
    (: update the existing domain :)
    if ($domain-id) then 
      let $_ :=
        xdmp:eval(
          'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
           declare variable $domain-name external;
           declare variable $description external;
           declare variable $domain-scope external;
           declare variable $context external;
           declare variable $pipeline-ids external;
           declare variable $permissions external;

           dom:set-description($domain-name, $description),
           dom:set-domain-scope($domain-name, $domain-scope),
           dom:set-evaluation-context($domain-name, $context),
           dom:set-pipelines($domain-name, $pipeline-ids/id/xs:unsignedLong(.)),
           dom:set-permissions($domain-name, $permissions/*:permission)',
          (xs:QName("domain-name"), $domain-name,
           xs:QName("description"), $description,
           xs:QName("domain-scope"), $domain-scope,
           xs:QName("context"), $context,
           xs:QName("pipeline-ids"), 
            <ids>
            { 
              for $id in $pipeline-ids
              return <id>{$id}</id>
            }
            </ids>,
           xs:QName("permissions"), $permissions),
          <options xmlns="xdmp:eval">
            <database>{xdmp:triggers-database()}</database>
          </options>
        )
      return
        $domain-id
    (: create a new domain and return its id :)
    else
      xdmp:eval(
        'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
         declare variable $domain-name external;
         declare variable $description external;
         declare variable $domain-scope external;
         declare variable $context external;
         declare variable $pipeline-ids external;
         declare variable $permissions external;

         dom:create($domain-name, $description, $domain-scope, $context, $pipeline-ids/id/xs:unsignedLong(.), $permissions/*:permission)',
        (xs:QName("domain-name"), $domain-name,
         xs:QName("description"), $description,
         xs:QName("domain-scope"), $domain-scope,
         xs:QName("context"), $context,
         xs:QName("pipeline-ids"), 
          <ids>
          { 
            for $id in $pipeline-ids
            return <id>{$id}</id>
          }
          </ids>,
         xs:QName("permissions"), $permissions),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
        </options>)
};

declare private function cpf:configuration-get() as element(dom:configuration)?
{
  xdmp:eval(
    'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
     try { dom:configuration-get() } catch($e) {}',
    (),
    <options xmlns="xdmp:eval">
      <database>{xdmp:triggers-database()}</database>
    </options>
  )
};

declare function cpf:update-config(
  $config as element(dom:configuration)?,
  $restart-user as xs:string,
  $evaluation-context as element(dom:evaluation-context),
  $default-domain as xs:unsignedLong,
  $permissions as element(permissions)
)
{
  xdmp:eval(
    'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
     declare variable $config external;
     declare variable $restart-user external;
     declare variable $evaluation-context external;
     declare variable $default-domain external;
     declare variable $permissions external;

     let $config := dom:configuration-set-restart-user($restart-user)
     let $config := dom:configuration-set-evaluation-context($evaluation-context)
     let $config := dom:configuration-set-default-domain($default-domain)
     let $config := dom:configuration-set-permissions($permissions/*:permission)
     let $config := dom:configuration-set-conversion-enabled(fn:false())
     return
       "Updated configuration"',
    (xs:QName("config"), $config,
     xs:QName("restart-user"), $restart-user,
     xs:QName("evaluation-context"), $evaluation-context,
     xs:QName("default-domain"), $default-domain,
     xs:QName("permissions"), $permissions),
    <options xmlns="xdmp:eval">
      <database>{xdmp:triggers-database()}</database>
    </options>
  )
};

declare private function cpf:configuration-create(
  $restart-user as xs:string,
  $evaluation-context as element(dom:evaluation-context),
  $default-domain as xs:unsignedLong,
  $permissions as element(permissions),
  $enable as xs:boolean)
{
  xdmp:eval(
    'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
     declare variable $restart-user external;
     declare variable $evaluation-context external;
     declare variable $default-domain external;
     declare variable $permissions external;
     
     dom:configuration-create($restart-user, $evaluation-context, $default-domain, $permissions/*:permission)',
    (xs:QName("restart-user"), $restart-user,
     xs:QName("evaluation-context"), $evaluation-context,
     xs:QName("default-domain"), $default-domain,
     xs:QName("permissions"), $permissions),
    <options xmlns="xdmp:eval">
      <database>{xdmp:triggers-database()}</database>
      <isolation>different-transaction</isolation>
    </options>
  ),
  xdmp:eval(
    'import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
     declare variable $enable external;
     dom:configuration-set-conversion-enabled($enable)',
    (xs:QName("enable"), $enable),
    <options xmlns="xdmp:eval">
      <database>{xdmp:triggers-database()}</database>
      <isolation>different-transaction</isolation>
    </options>
  )  
};

(:
 : Creates a cpf configuration. If the configuration already exists it is updated.
 :
 : @param $restart-user - The username for the user who runs the restart trigger.
 : @param $evaluation-context - The evaluation-context element (for example, from the output of dom:evaluation-context for the domain.
 : @param $default-domain - The ID of the default domain.
 : @param $permissions - Zero or more permissions elements.
 :)
declare function cpf:create-cpf-configuration(
  $restart-user as xs:string,
	$evaluation-context as element(dom:evaluation-context),
	$default-domain as xs:unsignedLong,
	$permissions as element(permissions))
{
  let $config := cpf:configuration-get()
  return
    if ($config) then
      cpf:update-config($config, $restart-user, $evaluation-context, $default-domain, $permissions)
    else
      cpf:configuration-create($restart-user, $evaluation-context, $default-domain, $permissions, fn:false())
};

(:
 : A handy wrapper for dom:domain-scope so you don't
 : have to include the dom into your xquery code
 :
 : @param $document-scope - The way in which this domain scope is defined: "collection", "directory", or "document".
 : @param $uri - The URI defining the scoping. For a "collection" scope this will be the collection URI; for a "directory" scope this will be the URI of the directory (and must therefore end with a trailing slash); for a "document" scope this will be the URI of the document.
 : @param $depth - This parameter applies only to "directory" scopes and defines whether the scope is recursive ("infinity") or not ("0").
 : @return - a constructed dom:domain-scope element
 :)
declare function cpf:domain-scope(
  $document-scope as xs:string,
  $uri as xs:string,
  $depth as xs:string?) as element(dom:domain-scope)
{
  dom:domain-scope($document-scope, $uri, $depth)
};

(:
 : Handy wrapper for dom:evaluation-context so you don't
 : have to include the dom into your xquery code
 :
 : @param $database - The unique identifier of the database in which the content processing actions will be executed. All the modules used in the content processing application must be in this database.
 : @param $root - A root path under which modules are located.
 : @return - a constructed dom:evaluation-context element
 :)
declare function cpf:evaluation-context(
	$database as xs:unsignedLong,
	$root as xs:string) as element(dom:evaluation-context)
{
  dom:evaluation-context($database, $root)
};

(:
 : Given the name of a domain get the id (if it exists)
 :
 : @param $name - the name of the domain
 : @return - the id of the domain
 :)
declare function cpf:get-domain-id($name as xs:string) as xs:unsignedLong?
{
  try { fn:data(dom:get($name)/dom:domain-id) } catch ($e) { () }
};

(:
declare private function cpf:call-private-function(
  $map as map:map,
  $database-id as xs:unsignedLong)
{
  xdmp:invoke(
    "/roxy/lib/cpf-private.xqy",
    (xs:QName("map"), $map),
    <options xmlns="xdmp:eval">
		  <database>{$database-id}</database>
	  </options>)
};
:)