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

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

declare namespace setup = "http://marklogic.com/roxy/setup";
declare namespace display = "http://marklogic.com/roxy/setup/display";
declare namespace xdmp="http://marklogic.com/xdmp";
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace db="http://marklogic.com/xdmp/database";
declare namespace gr="http://marklogic.com/xdmp/group";
declare namespace err="http://marklogic.com/xdmp/error";
declare namespace ho="http://marklogic.com/xdmp/hosts";
declare namespace as="http://marklogic.com/xdmp/assignments";
declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace mt="http://marklogic.com/xdmp/mimetypes";
declare namespace pki="http://marklogic.com/xdmp/pki";

declare option xdmp:mapping "false";

declare variable $default-group := xdmp:group();
declare variable $default-host := xdmp:host();
declare variable $default-database := xdmp:database();
declare variable $default-modules := xdmp:database("Modules");
declare variable $default-schemas := xdmp:database("Schemas");
declare variable $default-security := xdmp:database("Security");
declare variable $default-user := xdmp:user("nobody");

declare variable $context-path := fn:resolve-uri(".", xdmp:get-request-path());

declare variable $roll-back := map:map();

declare variable $restart-needed as xs:boolean := fn:false();

(: A note on naming conventions:
  $admin-config refers to the configuration passed around by the Admin APIs
  $import-config is the import/export configuration format that setup:get-configuration() generates
:)

declare function setup:add-rollback(
  $key as xs:string,
  $value as item()+)
{
  map:put(
        $roll-back,
        $key,
        (map:get($roll-back, $key), $value))
};

declare function setup:get-rollback-config()
{
  let $config :=
    element configuration
    {
      element gr:http-servers
      {
        map:get($roll-back, "http-servers")
      },
      element gr:xdbc-servers
      {
        map:get($roll-back, "xdbc-servers")
      },
      element db:databases
      {
        map:get($roll-back, "databases")
      },
      element as:assignments
      {
        map:get($roll-back, "assignments")
      },
      element mt:mimetypes
      {
        map:get($roll-back, "mimetypes")
      },
      element sec:amps
      {
        map:get($roll-back, "amps")
      },
      element sec:users
      {
        map:get($roll-back, "users")
      },
      element sec:roles
      {
        map:get($roll-back, "roles")
      },
      element sec:privileges
      {
        map:get($roll-back, "privileges")
      }
    }
  return
    $config
};

declare function setup:do-setup($import-config as element(configuration)) as item()*
{
  try
  {
    setup:create-privileges($import-config),
    setup:create-roles($import-config),
    setup:create-users($import-config),
    setup:create-mimetypes($import-config),
    setup:create-forests($import-config),
    setup:create-databases($import-config),
    setup:attach-forests($import-config),
    setup:create-amps($import-config),
    setup:apply-database-settings($import-config),
    setup:configure-databases($import-config),
    setup:create-appservers($import-config),
    setup:apply-appservers-settings($import-config),
    if ($restart-needed) then
      "note: restart required"
    else ()
  }
  catch($ex)
  {
    setup:do-wipe(setup:get-rollback-config()),
    $ex
  }
};

declare function setup:do-wipe($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $groupid := xdmp:group()
  let $remove-appservers :=
    for $as-name in ($import-config/gr:http-servers/gr:http-server/gr:http-server-name,
                     $import-config/gr:xdbc-servers/gr:xdbc-server/gr:xdbc-server-name)
    return
      if (admin:appserver-exists($admin-config, $groupid, $as-name)) then
        xdmp:set(
          $admin-config,
          admin:appserver-delete(
            $admin-config,
            admin:appserver-get-id($admin-config, $groupid, $as-name)))
      else ()
  return
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),

  let $admin-config := admin:get-configuration()
  for $amp in $import-config/sec:amps/sec:amp
  where admin:database-exists($admin-config, $amp/sec:db-name)
  return
    try
    {
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $amp external;
         if (sec:amp-exists($amp/sec:namespace, $amp/sec:local-name, $amp/sec:doc-uri, xdmp:database($amp/sec:db-name))) then
           sec:remove-amp(
             $amp/sec:namespace,
             $amp/sec:local-name,
             $amp/sec:doc-uri,
             xdmp:database($amp/sec:db-name))
         else ()',
        (xs:QName("amp"), $amp),
        <options xmlns="xdmp:eval">
          <database>{xdmp:database("Security")}</database>
        </options>)
    }
    catch($ex)
    {
      if ($ex/error:code = "SEC-AMPDNE") then ()
      else
        xdmp:rethrow()
    },

  for $db-config in $import-config/db:databases/db:database
  return
    setup:delete-database-and-forests($db-config),

  (: Even though we delete forests that are attached to the database above, we will delete
   : forests named in the config file. When named forests are in use, we'll be able to
   : delete them even if they aren't attached to the database for whatever reason. :)
  let $admin-config := admin:get-configuration()
  let $remove-forests :=
    for $forest-name in $import-config/as:assignments/as:assignment/as:forest-name
    return
      if (admin:forest-exists($admin-config, $forest-name)) then
        xdmp:set(
          $admin-config,
          admin:forest-delete(
            $admin-config,
            admin:forest-get-id($admin-config, $forest-name), fn:true()))
      else ()
  return
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),

  let $admin-config := admin:get-configuration()
  let $remove-mimetypes :=
    for $x in $import-config/mt:mimetypes/mt:mimetype
    return
      try
      {
        xdmp:set(
          $admin-config,
          admin:mimetypes-delete(
            $admin-config,
            admin:mimetype($x/mt:name, $x/mt:extension, $x/mt:format)))
      }
      catch($ex)
      {
        if ($ex/error:code = "ADMIN-NOSUCHITEM") then ()
        else
          xdmp:rethrow()
      }
  return
    admin:save-configuration($admin-config),

  for $user in $import-config/sec:users/sec:user/sec:user-name
  return
    try
    {
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $user as xs:string external;
         sec:remove-user($user)',
        (xs:QName("user"), $user),
        <options xmlns="xdmp:eval">
          <database>{xdmp:database("Security")}</database>
        </options>)
    }
    catch($ex)
    {
      if ($ex/error:code = "SEC-USERDNE") then ()
      else
        xdmp:rethrow()
    },

  for $role in $import-config/sec:roles/sec:role/sec:role-name
  return
    try
    {
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $role as xs:string external;
         sec:remove-role($role)',
        (xs:QName("role"), $role),
        <options xmlns="xdmp:eval">
          <database>{xdmp:database("Security")}</database>
        </options>)
    }
    catch($ex)
    {
      if ($ex/error:code = "SEC-ROLEDNE") then ()
      else
        xdmp:rethrow()
    },

  for $priv in $import-config/sec:privileges/sec:privilege
  return
    try
    {
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $action as xs:string external;
         declare variable $kind as xs:string external;
         sec:remove-privilege($action, $kind)',
        (xs:QName("action"), $priv/sec:action,
         xs:QName("kind"), $priv/sec:kind),
        <options xmlns="xdmp:eval">
          <database>{xdmp:database("Security")}</database>
        </options>)
    }
    catch($ex)
    {
      if ($ex/error:code = "SEC-PRIVDNE") then ()
      else
        xdmp:rethrow()
    },

  if ($restart-needed) then
    "note: restart required"
  else ()
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Delete a database and any forests that are attached
 :: to it.
 ::)

declare function setup:delete-database-and-forests($db-config as element(db:database))
{
  let $db-name := $db-config/db:database-name
  let $admin-config := admin:get-configuration()
  return
    if (admin:database-exists($admin-config, $db-name)) then
      let $db-id := admin:database-get-id($admin-config, $db-name)
      let $forest-ids := admin:database-get-attached-forests($admin-config, $db-id)
      let $detach :=
      (
        for $id in $forest-ids
        return
          xdmp:set($admin-config, admin:database-detach-forest($admin-config, $db-id, $id)),
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else ()
      )
      let $admin-config := admin:get-configuration()
      let $forest-ids :=
        if (fn:exists($forest-ids)) then
          $forest-ids
        else
          (: For the case where the database exists but the forests are detached :)
          setup:find-forest-ids($db-config)
      let $admin-config := admin:forest-delete($admin-config, $forest-ids, fn:true())
      let $admin-config := admin:database-delete($admin-config, $db-id)
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else ()
    else
      (: The database does not exist. Check for the forests anyway :)
      let $forest-ids := setup:find-forest-ids($db-config)
      let $admin-config := admin:forest-delete($admin-config, $forest-ids, fn:true())
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else ()
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Restart the target group.
 ::)
declare function setup:do-restart($group-name as xs:string?) as item()*
{
  try
  {
    let $group-id :=
      if ($group-name = "") then
        xdmp:group()
      else
        xdmp:group($group-name)
    return
    (
      xdmp:restart(
        xdmp:group-hosts($group-id),
        "Restarting hosts to make configuration changes take effect"),
      fn:concat($group-name, "Group restarted")
    )
  }
  catch ($e)
  {
    if ($e/error:code = "XDMP-NOSUCHGROUP") then
      fn:concat("Cannot restart group ", $group-name, ", no such group")
    else
      xdmp:rethrow()
  }
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:find-forest-ids(
  $db-config as element(db:database)) as xs:unsignedLong*
{
  let $group-id := xdmp:group()
  let $admin-config := admin:get-configuration()
  let $hosts := admin:group-get-host-ids($admin-config, $group-id)
  let $data-directory := $db-config/db:forests/db:data-directory
  for $host at $i in $hosts
  for $j in (1 to $db-config/db:forests-per-host)
  let $name :=
    fn:string-join((
      $db-config/db:database-name,
      xdmp:host-name($host),
      xs:string($j)),
      "-")
  return
    if (admin:forest-exists($admin-config, $name)) then
      admin:forest-get-id($admin-config, $name)
    else ()
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of mimetypes
 ::)

declare function setup:create-mimetypes($import-config as element(configuration)) as item()*
{
  for $mimetype-config in $import-config/mt:mimetypes/mt:mimetype
  let $name as xs:string := $mimetype-config/mt:name
  let $extension as xs:string := $mimetype-config/mt:extension
  let $format as xs:string := $mimetype-config/mt:format
  let $admin-config := admin:get-configuration()
  return
    if (admin:mimetypes-get($admin-config)[mt:name = $name]) then
      fn:concat("Mimetype ", $name, " already exists, not recreated..")
    else
      let $admin-config :=
        admin:mimetypes-add($admin-config, admin:mimetype($name, $extension, $format))
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        setup:add-rollback("mimetypes", $mimetype-config),
        fn:concat("Mimetype ", $name, " succesfully created")
      )
};

declare function setup:validate-mimetypes($import-config as element(configuration))
{
  for $mimetype-config in $import-config/mt:mimetypes/mt:mimetype
  let $name as xs:string := $mimetype-config/mt:name
  let $extension as xs:string := $mimetype-config/mt:extension
  let $format as xs:string := $mimetype-config/mt:format
  let $admin-config := admin:get-configuration()
  let $match := admin:mimetypes-get($admin-config)[mt:name = $name]
  return
    if ($match) then
      if ($match/mt:extension != $extension or $match/mt:format != $format) then
        setup:validation-fail(fn:concat("Mimetype mismatch: ", $name))
      else
        ()
    else
      setup:validation-fail(fn:concat("Missing mimetype: ", $name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of forests
 ::)

declare function setup:create-forests($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host := $db-config/db:forests-per-host
  return
    if (fn:exists($forests-per-host)) then
      setup:create-forests-from-count($db-config, $database-name, $forests-per-host)
    else
      setup:create-forests-from-config($import-config, $db-config, $database-name)
};

declare function setup:validate-forests($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host := $db-config/db:forests-per-host
  return
    if (fn:exists($forests-per-host)) then
      setup:validate-forests-from-count($db-config, $database-name, $forests-per-host)
    else
      setup:validate-forests-from-config($import-config, $db-config, $database-name)
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:create-forests-from-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string) as item()*
{
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  let $forest-name as xs:string? := $forest-config/as:forest-name[fn:string-length(.) > 0]
  let $data-directory as xs:string? := $forest-config/as:data-directory[fn:string-length(.) > 0]
  let $host-name as xs:string? := $forest-config/as:host[fn:string-length(.) > 0]
  return
    setup:create-forest(
      $forest-name,
      $data-directory,
      if ($host-name) then xdmp:host($host-name) else ())

};

declare function setup:validate-forests-from-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string)
{
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  let $forest-name as xs:string? := $forest-config/as:forest-name[fn:string-length(.) > 0]
  let $data-directory as xs:string? := $forest-config/as:data-directory[fn:string-length(.) > 0]
  let $host-name as xs:string? := $forest-config/as:host[fn:string-length(.) > 0]
  return
    setup:validate-forest(
      $forest-name,
      $data-directory,
      if ($host-name) then xdmp:host($host-name) else ())
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:create-forests-from-count(
  $db-config as element(db:database),
  $database-name as xs:string,
  $forests-per-host as xs:int) as item()*
{
  let $data-directory := $db-config/db:forests/db:data-directory
  for $host at $i in admin:group-get-host-ids(admin:get-configuration(), xdmp:group())
  for $j in (1 to $forests-per-host)
  let $forest-name := fn:string-join(($database-name, xdmp:host-name($host), xs:string($j)), "-")
  return
    setup:create-forest(
      $forest-name,
      $data-directory,
      $host)
};

declare function setup:validate-forests-from-count(
  $db-config as element(db:database),
  $database-name as xs:string,
  $forests-per-host as xs:int)
{
  let $data-directory := $db-config/db:forests/db:data-directory
  for $host at $i in admin:group-get-host-ids(admin:get-configuration(), xdmp:group())
  for $j in (1 to $forests-per-host)
  let $forest-name := fn:string-join(($database-name, xdmp:host-name($host), xs:string($j)), "-")
  return
    setup:validate-forest(
      $forest-name,
      $data-directory,
      $host)
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:get-database-forest-configs(
  $import-config as element(configuration),
  $db as xs:string) as element(as:assignment)*
{
  $import-config/as:assignments/as:assignment[
    as:forest-name = $import-config/db:databases/db:database[db:database-name = $db]/db:forests/db:forest-id/@name]
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:create-forest(
  $forest-name as xs:string,
  $data-directory as xs:string?,
  $host-id as xs:unsignedLong?) as item()*
{
  if (xdmp:forests()[$forest-name = xdmp:forest-name(.)]) then
    fn:concat("Forest ", $forest-name, " already exists, not recreated..")
  else
    let $host := ($host-id, $default-host)[1]
    let $admin-config :=
      admin:forest-create(admin:get-configuration(), $forest-name, $host, $data-directory)
    return
    (
      if (admin:save-configuration-without-restart($admin-config)) then
        xdmp:set($restart-needed, fn:true())
      else (),
      setup:add-rollback(
        "assignments",
        element as:assignment
        {
          element as:forest-name { $forest-name }
        }),
      fn:string-join((
        "Forest ", $forest-name, " succesfully created",
        if ($data-directory) then (" at ", $data-directory)
        else (),
        if ($host) then (" on ", xdmp:host-name($host))
        else ()), "")
    )
};

declare function setup:validate-forest(
  $forest-name as xs:string,
  $data-directory as xs:string?,
  $host-id as xs:unsignedLong?)
{
  if (xdmp:forests()[$forest-name = xdmp:forest-name(.)]) then
    let $forest-id := xdmp:forest($forest-name)
    let $admin-config := admin:get-configuration()
    return
    (
      if ($data-directory) then
        let $actual := admin:forest-get-data-directory($admin-config, $forest-id)
        return
          if ($actual = $data-directory) then ()
          else
            setup:validation-fail(fn:concat("Forest data directory mismatch: ", $data-directory, " != ", $actual))
      else (),

      if ($host-id) then
        let $actual := admin:forest-get-host($admin-config, $forest-id)
        return
          if ($actual = $host-id) then ()
          else
            setup:validation-fail(fn:concat("Forest host mismatch: ", $host-id, " != ", $actual))
      else ()
    )
  else
    setup:validation-fail(fn:concat("Forest missing: ", $forest-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of databases
 ::)

declare function setup:create-databases($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  return
    if (xdmp:databases()[xdmp:database-name(.) = $database-name]) then
      fn:concat("Database ", $database-name, " already exists, not recreated..")
    else
      let $admin-config :=
        admin:database-create(
          admin:get-configuration(),
          $database-name,
          $default-security,
          $default-schemas)
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        setup:add-rollback("databases", $db-config),
        fn:concat("Database ", $database-name, " succesfully created.")
      )
};

declare function setup:validate-databases($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  return
    if (xdmp:databases()[xdmp:database-name(.) = $database-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing database: ", $database-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Attaching forests to databases
 ::)

declare function setup:attach-forests($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host := $db-config/db:forests-per-host
  let $forest-config := setup:get-database-forest-configs($import-config, $database-name)
  return
    if (fn:exists($forests-per-host)) then
      setup:attach-forests-by-count($db-config)
    else
      setup:attach-forests-by-config($import-config, $db-config, $database-name)
};

declare function setup:validate-attached-forests($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host := $db-config/db:forests-per-host
  let $forest-config := setup:get-database-forest-configs($import-config, $database-name)
  return
    if (fn:exists($forests-per-host)) then
      setup:validate-attached-forests-by-count($db-config)
    else
      setup:validate-attached-forests-by-config($import-config, $db-config, $database-name)
};

declare function setup:attach-forests-by-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string) as item()*
{
  for $forest-ref in $db-config/db:forests/db:forest-id
  return
    setup:attach-database-forest($database-name, $forest-ref/@name)
};

declare function setup:validate-attached-forests-by-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string)
{
  for $forest-ref in $db-config/db:forests/db:forest-id
  return
    setup:validate-attached-database-forest($database-name, $forest-ref/@name)
};

declare function setup:attach-forests-by-count($db-config as element(db:database)) as item()*
{
  let $database-name := setup:get-database-name-from-database-config($db-config)
  for $host in admin:group-get-host-ids(admin:get-configuration(), xdmp:group())
  let $hostname := xdmp:host-name($host)
  for $j in (1 to setup:get-forests-per-host-from-database-config($db-config))
  let $forest-name := fn:string-join(($database-name, $hostname, xs:string($j)), "-")
  return
    setup:attach-database-forest($database-name, $forest-name)
};

declare function setup:validate-attached-forests-by-count($db-config as element(db:database))
{
  let $database-name := setup:get-database-name-from-database-config($db-config)
  for $host in admin:group-get-host-ids(admin:get-configuration(), xdmp:group())
  let $hostname := xdmp:host-name($host)
  for $j in (1 to setup:get-forests-per-host-from-database-config($db-config))
  let $forest-name := fn:string-join(($database-name, $hostname, xs:string($j)), "-")
  return
    setup:validate-attached-database-forest($database-name, $forest-name)
};

declare function setup:attach-database-forest(
  $database-name as xs:string, $forest-name as xs:string) as item()*
{
  let $db := xdmp:database($database-name)
  let $forest := xdmp:forest($forest-name)
  let $admin-config := admin:get-configuration()

  (: if the forests are already attached we need to detach them first :)
  let $admin-config :=
    if (xdmp:database-forests(xdmp:database($database-name))[$forest-name = xdmp:forest-name(.)]) then
      admin:database-detach-forest($admin-config, $db, $forest)
    else
      $admin-config
  let $admin-config := admin:database-attach-forest($admin-config, $db, $forest)
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("Forest ", $forest-name, " succesfully attached to database ", $database-name)
  )
};

declare function setup:validate-attached-database-forest(
  $database-name as xs:string, $forest-name as xs:string)
{
  let $db := xdmp:database($database-name)
  let $forest := xdmp:forest($forest-name)
  let $admin-config := admin:get-configuration()
  return
    if (xdmp:database-forests(xdmp:database($database-name))[$forest-name = xdmp:forest-name(.)]) then ()
    else
      setup:validation-fail(fn:concat("Forest not attached to database: ", $forest-name, " => ", $database-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Applying of database settings
 ::)

declare function setup:apply-database-settings($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $database := xdmp:database($database-name)
  let $settings :=
    <settings>
      <setting>language</setting>
      <setting>stemmed-searches</setting>
      <setting>word-searches</setting>
      <setting>word-positions</setting>
      <setting>fast-phrase-searches</setting>
      <setting>fast-reverse-searches</setting>
      <setting>fast-case-sensitive-searches</setting>
      <setting>fast-diacritic-sensitive-searches</setting>
      <setting>fast-element-word-searches</setting>
      <setting>element-word-positions</setting>
      <setting>fast-element-phrase-searches</setting>
      <setting>element-value-positions</setting>
      <setting>attribute-value-positions</setting>
      <setting>three-character-searches</setting>
      <setting>three-character-word-positions</setting>
      <setting>fast-element-character-searches</setting>
      <setting>trailing-wildcard-searches</setting>
      <setting>trailing-wildcard-word-positions</setting>
      <setting>fast-element-trailing-wildcard-searches</setting>
      <setting>two-character-searches</setting>
      <setting>one-character-searches</setting>
      <setting>uri-lexicon</setting>
      <setting>collection-lexicon</setting>
      <setting>reindexer-enable</setting>
      <setting>reindexer-throttle</setting>
      <setting>reindexer-timestamp</setting>
      <setting>directory-creation</setting>
      <setting>maintain-last-modified</setting>
      <setting>maintain-directory-last-modified</setting>
      <setting>inherit-permissions</setting>
      <setting>inherit-collections</setting>
      <setting>inherit-quality</setting>
      <setting>format-compatibility</setting>
      <setting>index-detection</setting>
      <setting>expunge-locks</setting>
      <setting>tf-normalization</setting>
    </settings>
  let $apply-settings :=
    for $setting in $settings/*:setting
    let $value := fn:data(xdmp:value(fn:concat("$db-config/db:", $setting)))
    where fn:exists($value)
    return
      xdmp:set(
        $admin-config,
        xdmp:value(fn:concat("admin:database-set-", $setting, "($admin-config, $database, $value)")))
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),

    fn:concat("Database ", $database-name, " settings applied succesfully.")
  )
};

declare function setup:validate-database-settings($import-config as element(configuration))
{
  let $admin-config := admin:get-configuration()
  for $db-config in setup:get-databases-from-config($import-config)
  let $database := xdmp:database(setup:get-database-name-from-database-config($db-config))
  let $settings :=
    <settings>
      <setting>language</setting>
      <setting>stemmed-searches</setting>
      <setting>word-searches</setting>
      <setting>word-positions</setting>
      <setting>fast-phrase-searches</setting>
      <setting>fast-reverse-searches</setting>
      <setting>fast-case-sensitive-searches</setting>
      <setting>fast-diacritic-sensitive-searches</setting>
      <setting>fast-element-word-searches</setting>
      <setting>element-word-positions</setting>
      <setting>fast-element-phrase-searches</setting>
      <setting>element-value-positions</setting>
      <setting>attribute-value-positions</setting>
      <setting>three-character-searches</setting>
      <setting>three-character-word-positions</setting>
      <setting>fast-element-character-searches</setting>
      <setting>trailing-wildcard-searches</setting>
      <setting>trailing-wildcard-word-positions</setting>
      <setting>fast-element-trailing-wildcard-searches</setting>
      <setting>two-character-searches</setting>
      <setting>one-character-searches</setting>
      <setting>uri-lexicon</setting>
      <setting>collection-lexicon</setting>
      <setting>reindexer-enable</setting>
      <setting>reindexer-throttle</setting>
      <setting>reindexer-timestamp</setting>
      <setting>directory-creation</setting>
      <setting>maintain-last-modified</setting>
      <setting>maintain-directory-last-modified</setting>
      <setting>inherit-permissions</setting>
      <setting>inherit-collections</setting>
      <setting>inherit-quality</setting>
      <setting>format-compatibility</setting>
      <setting>index-detection</setting>
      <setting>expunge-locks</setting>
      <setting>tf-normalization</setting>
    </settings>
  for $setting in $settings/*:setting
  let $expected := fn:data(xdmp:value(fn:concat("$db-config/db:", $setting)))
  let $actual := xdmp:value(fn:concat("admin:database-get-", $setting, "($admin-config, $database)"))
  where fn:exists($expected)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("database ", $setting, " mismatch: ", $expected, " != ", $actual))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Configuration of databases
 ::)

declare function setup:configure-databases($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $database := xdmp:database($database-name)

  let $remove-existing-range-path-indexes :=
    (: wrap in try catch because this function is new to 6.0 and will fail in older version of ML :)
    try
    {
      if (xdmp:eval('
          import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
          declare variable $database external;
          let $admin-config := admin:get-configuration()
          let $remove-existing-indexes :=
            for $index in admin:database-get-range-path-indexes($admin-config, $database)
            return
              xdmp:set(
                $admin-config,
                admin:database-delete-range-path-index($admin-config, $database, $index))
          return
            admin:save-configuration-without-restart($admin-config)',
          (xs:QName("database"), $database))) then
        xdmp:set($restart-needed, fn:true())
      else ()
    }
    catch($ex)
    {
      if ($ex/error:code = "XDMP-UNDFUN") then ()
      else
        xdmp:rethrow()
    }

  let $remove-existing-path-namespaces :=
    (: wrap in try catch because this function is new to 6.0 and will fail in older version of ML :)
    try
    {
      if (xdmp:eval('
          import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
          declare variable $database external;
          let $admin-config := admin:get-configuration()
          let $remove-existing-indexes :=
            for $index in admin:database-get-path-namespaces($admin-config, $database)
            return
              xdmp:set($admin-config, admin:database-delete-path-namespace($admin-config, $database, $index))
          return
            admin:save-configuration-without-restart($admin-config)',
          (xs:QName("database"), $database))) then
        xdmp:set($restart-needed, fn:true())
      else ()
    }
    catch($ex)
    {
      if ($ex/error:code = "XDMP-UNDFUN") then ()
      else
        xdmp:rethrow()
    }

  let $admin-config := setup:add-word-lexicons(admin:get-configuration(), $database, $db-config)
  let $admin-config := setup:add-fragment-roots($admin-config, $database, $db-config)
  let $admin-config := setup:add-fragment-parents($admin-config, $database, $db-config)

  let $admin-config := setup:config-word-query($admin-config, $database, $db-config)
  (:
    <element-word-query-throughs />
    <phrase-throughs />
    <phrase-arounds />
    <geospatial-element-indexes />

  :)

  let $admin-config := setup:set-schema-database($admin-config, $db-config, $database)
  let $admin-config := setup:set-security-database($admin-config, $db-config, $database)
  let $admin-config := setup:set-triggers-database($admin-config, $db-config, $database)

  (: remove any existing range index (copied from default.xqy) :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-range-element-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-range-element-index($admin-config, $database, $index))

  let $admin-config := setup:add-range-element-indexes($admin-config, $database, $db-config)

  (: remove any existing range element attribute index :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-range-element-attribute-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-range-element-attribute-index($admin-config, $database, $index))

  let $admin-config := setup:add-range-element-attribute-indexes($admin-config, $database, $db-config)

  let $admin-config := setup:add-path-namespaces($admin-config, $database, $db-config)
  let $admin-config := setup:add-range-path-indexes($admin-config, $database, $db-config)

  (: remove any existing geospatial element attribute pair indexes :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-geospatial-element-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-geospatial-element-index($admin-config, $database, $index))

  let $admin-config := setup:add-geospatial-element-indexes($admin-config, $database, $db-config)

  (: remove any existing geospatial element attribute pair indexes :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-geospatial-element-attribute-pair-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-geospatial-element-attribute-pair-index($admin-config, $database, $index))

  let $admin-config := setup:add-geospatial-element-attribute-pair-indexes($admin-config, $database, $db-config)

  (: remove any existing geospatial element  pair indexes :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-geospatial-element-pair-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-geospatial-element-pair-index($admin-config, $database, $index))

  let $admin-config := setup:add-geospatial-element-pair-indexes($admin-config, $database, $db-config)

  (: remove any existing geospatial element  pair indexes :)
  let $remove-existing-indexes :=
    for $index in admin:database-get-geospatial-element-child-indexes($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-geospatial-element-child-index($admin-config, $database, $index))

  let $admin-config := setup:add-geospatial-element-child-indexes($admin-config, $database, $db-config)

  (: remove any existing field (copied from default.xqy) :)
  let $remove-existing-fields :=
    for $field as xs:string in admin:database-get-fields($admin-config, $database)/db:field-name[fn:not(. = "")]
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-field($admin-config, $database, $field))

  let $admin-config := setup:add-fields($admin-config, $database, $db-config)
  let $admin-config := setup:add-field-includes($admin-config, $database, $db-config)
  let $admin-config := setup:add-field-excludes($admin-config, $database, $db-config)


  let $remove-existing-indexes :=
    (: wrap in try catch because this function is new to 5.0 and will fail in older version of ML :)
    try
    {
      xdmp:set(
        $admin-config,
        xdmp:eval('
          import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
          declare variable $admin-config external;
          declare variable $database external;

          let $remove-existing-indexes :=
            for $index in admin:database-get-range-field-indexes($admin-config, $database)
            return
              xdmp:set(
                $admin-config,
                admin:database-delete-range-field-index($admin-config, $database, $index))
          return
            $admin-config',
          (xs:QName("admin-config"), $admin-config,
           xs:QName("database"), $database)))
    }
    catch($ex)
    {
      if ($ex/error:code = "XDMP-UNDFUN") then ()
      else
        xdmp:rethrow()
    }

  let $admin-config := setup:add-range-field-indexes($admin-config, $database, $db-config)

  let $remove-existing-element-word-lexicons :=
    for $lexicon in admin:database-get-element-word-lexicons($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-element-word-lexicon($admin-config, $database, $lexicon))
  let $admin-config := setup:add-element-word-lexicons($admin-config, $database, $db-config)

  let $remove-existing-element-attribute-word-lexicons :=
    for $lexicon in admin:database-get-element-attribute-word-lexicons($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-element-attribute-word-lexicon($admin-config, $database, $lexicon))
  let $admin-config := setup:add-element-attribute-word-lexicons($admin-config, $database, $db-config)

  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("Database ", $database-name, " configured succesfully.")
  )
};

(: TODO: YOU ARE HERE :)
declare function setup:validate-databases-indexes($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $database := xdmp:database($database-name)
  let $admin-config := admin:get-configuration()
  return
  (
    setup:validate-word-lexicons($admin-config, $database, $db-config),
    setup:validate-fragment-roots($admin-config, $database, $db-config),
    setup:validate-fragment-parents($admin-config, $database, $db-config),
    setup:validate-word-query($admin-config, $database, $db-config),
    setup:validate-schema-database($admin-config, $db-config, $database),
    setup:validate-security-database($admin-config, $db-config, $database),
    setup:validate-triggers-database($admin-config, $db-config, $database),
    setup:validate-range-element-indexes($admin-config, $database, $db-config),
    setup:validate-range-element-attribute-indexes($admin-config, $database, $db-config),
    setup:validate-path-namespaces($admin-config, $database, $db-config),
    setup:validate-range-path-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-attribute-pair-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-pair-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-child-indexes($admin-config, $database, $db-config)(:,
    setup:validate-fields($admin-config, $database, $db-config),
    setup:validate-field-includes($admin-config, $database, $db-config),
    setup:validate-field-excludes($admin-config, $database, $db-config),
    setup:validate-range-field-indexes($admin-config, $database, $db-config),
    setup:validate-element-word-lexicons($admin-config, $database, $db-config),
    setup:validate-element-attribute-word-lexicons($admin-config, $database, $db-config):)
  )

};

declare function setup:add-fields(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-fields-R(
    $admin-config,
    $database,
    for $e in $db-config/db:fields/db:field[db:field-name != ""]
    return
      admin:database-field($e/db:field-name, $e/db:include-root))
};

declare function setup:add-fields-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $field-configs as element(db:field)*) as element(configuration)
{
  if ($field-configs) then
    setup:add-fields-R(
      admin:database-add-field($admin-config, $database, $field-configs[1]),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:add-field-includes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-field-includes-R(
    $admin-config,
    $database,
    $db-config/db:fields/db:field[db:field-name != ""])
};

declare function setup:add-field-includes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $field-configs as element(db:field)*) as element(configuration)
{
  if ($field-configs) then
    setup:add-field-includes-R(
      admin:database-add-field-included-element(
        $admin-config,
        $database,
        $field-configs[1]/db:field-name,
        for $e in $field-configs[1]/db:included-elements/db:included-element
        return
          admin:database-included-element(
            $e/db:namespace-uri,
            $e/db:localname,
            $e/db:weight,
            $e/db:attribute-namespace-uri,
            $e/db:attribute-localname,
            $e/db:attribute-value)),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:add-field-excludes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-field-excludes-R(
    $admin-config,
    $database,
    $db-config/db:fields/db:field[db:field-name != ""])
};

declare function setup:add-field-excludes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $field-configs as element(db:field)*) as element(configuration)
{
  if ($field-configs) then
    setup:add-field-excludes-R(
      admin:database-add-field-excluded-element(
        $admin-config,
        $database,
        $field-configs[1]/db:field-name,
        for $e in $field-configs[1]/db:excluded-elements/db:excluded-element
        return
          if (fn:starts-with(xdmp:version(), "4")) then
            admin:database-excluded-element(
              $e/db:namespace-uri,
              $e/db:localname)
          else
            xdmp:eval(
             'import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
              declare variable $e external;

              admin:database-excluded-element(
                $e/db:namespace-uri,
                $e/db:localname,
                $e/db:attribute-namespace-uri,
                $e/db:attribute-localname,
                $e/db:attribute-value)',
              (xs:QName("e"), $e),
              <options xmlns="xdmp:eval">
                <isolation>same-statement</isolation>
              </options>)),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:add-range-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-element-indexes-R(
    $admin-config,
    $database,
    $db-config/db:range-element-indexes/db:range-element-index)
};

declare function setup:add-range-element-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:range-element-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-range-element-indexes-R(
      admin:database-add-range-element-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-range-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-range-element-indexes($admin-config, $database)
  for $expected in $db-config/db:range-element-indexes/db:range-element-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing range element index: ", $expected/db:localname))
};

declare function setup:add-range-element-attribute-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-element-attribute-indexes-R(
    $admin-config,
    $database,
    $db-config/db:range-element-attribute-indexes/db:range-element-attribute-index)
};

declare function setup:add-range-element-attribute-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:range-element-attribute-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-range-element-attribute-indexes-R(
      admin:database-add-range-element-attribute-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-range-element-attribute-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-range-element-attribute-indexes($admin-config, $database)
  for $expected in $db-config/db:range-element-attribute-indexes/db:range-element-attribute-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing range element attribute index: ", $expected/db:localname))
};

declare function setup:add-path-namespaces(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-path-namespaces-R(
    $admin-config,
    $database,
    $db-config/db:path-namespaces/db:path-namespace)
};

declare function setup:add-path-namespaces-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:path-namespace)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-path-namespaces-R(
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $admin-config external;
        declare variable $database external;
        declare variable $index-config external;
        admin:database-add-path-namespace($admin-config, $database, $index-config)',
        (
          xs:QName("admin-config"), $admin-config,
          xs:QName("database"), $database,
          xs:QName("index-config"), $index-configs[1]
        )),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-path-namespaces(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing :=
    try
    {
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $admin-config external;
        declare variable $database external;
        admin:database-get-path-namespaces($admin-config, $database)',
        (
          xs:QName("admin-config"), $admin-config,
          xs:QName("database"), $database
        ))
    }
    catch($ex)
    {
      if ($ex/error:code = "XDMP-UNDFUN") then ()
      else
        xdmp:rethrow()
    }
  for $expected in $db-config/db:path-namespaces/db:path-namespace
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing path namespace: ", $expected/db:prefix, " => ", $expected/db:namespace-uri))
};

declare function setup:add-range-path-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-path-indexes-R(
    $admin-config,
    $database,
    $db-config/db:range-path-indexes/db:range-path-index)
};

declare function setup:add-range-path-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:range-path-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-range-path-indexes-R(
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $admin-config external;
        declare variable $database external;
        declare variable $index-config external;
        admin:database-add-range-path-index($admin-config, $database, $index-config)',
        (
          xs:QName("admin-config"), $admin-config,
          xs:QName("database"), $database,
          xs:QName("index-config"), $index-configs[1]
        )),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-range-path-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing :=
    try
    {
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $admin-config external;
        declare variable $database external;
        admin:database-get-range-path-indexes($admin-config, $database)',
        (
          xs:QName("admin-config"), $admin-config,
          xs:QName("database"), $database
        ))
    }
    catch($ex)
    {
      if ($ex/error:code = "XDMP-UNDFUN") then ()
      else
        xdmp:rethrow()
    }
  for $expected in $db-config/db:range-path-indexes/db:range-path-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing range path index: ", $expected/db:path-expression))
};

declare function setup:add-element-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-element-word-lexicons-R(
    $admin-config,
    $database,
    $db-config/db:element-word-lexicons/db:element-word-lexicon)
};

declare function setup:add-element-word-lexicons-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:element-word-lexicon)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-element-word-lexicons-R(
      admin:database-add-element-word-lexicon($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:add-element-attribute-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-element-attribute-word-lexicons-R(
    $admin-config,
    $database,
    $db-config/db:element-attribute-word-lexicons/db:element-attribute-word-lexicon)
};

declare function setup:add-element-attribute-word-lexicons-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:element-attribute-word-lexicon)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-element-attribute-word-lexicons-R(
      admin:database-add-element-attribute-word-lexicon($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};


declare function setup:add-range-field-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-field-indexes-R(
    $admin-config,
    $database,
    $db-config/db:range-field-indexes/db:range-field-index)
};

declare function setup:add-range-field-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:range-field-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-range-field-indexes-R(
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $admin-config external;
        declare variable $database external;
        declare variable $index-config external;
        admin:database-add-range-field-index($admin-config, $database, $index-config)',
        (
          xs:QName("admin-config"), $admin-config,
          xs:QName("database"), $database,
          xs:QName("index-config"), $index-configs[1]
        )),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};


declare function setup:add-geospatial-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-indexes-R(
    $admin-config,
    $database,
    $db-config/db:geospatial-element-indexes/db:geospatial-element-index)
};

declare function setup:add-geospatial-element-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:geospatial-element-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-geospatial-element-indexes-R(
      admin:database-add-geospatial-element-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-geospatial-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-geospatial-element-indexes($admin-config, $database)
  for $expected in $db-config/db:geospatial-element-indexes/db:geospatial-element-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing geospatial element index: ", $expected/db:localname))
};

declare function setup:add-geospatial-element-attribute-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-attribute-pair-indexes-R(
    $admin-config,
    $database,
    $db-config/db:geospatial-element-attribute-pair-indexes/db:geospatial-element-attribute-pair-index)
};

declare function setup:add-geospatial-element-attribute-pair-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:geospatial-element-attribute-pair-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-geospatial-element-attribute-pair-indexes-R(
      admin:database-add-geospatial-element-attribute-pair-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-geospatial-element-attribute-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-geospatial-element-attribute-pair-indexes($admin-config, $database)
  for $expected in $db-config/db:geospatial-element-attribute-pair-indexes/db:geospatial-element-attribute-pair-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing geospatial element attribute pair index: ", $expected/db:localname))
};

declare function setup:add-geospatial-element-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-pair-indexes-R(
    $admin-config,
    $database,
    $db-config/db:geospatial-element-pair-indexes/db:geospatial-element-pair-index)
};

declare function setup:add-geospatial-element-pair-indexes-R(
  $admin-config as element(configuration), $database as xs:unsignedLong,
  $index-configs as element(db:geospatial-element-pair-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-geospatial-element-pair-indexes-R(
      admin:database-add-geospatial-element-pair-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-geospatial-element-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-geospatial-element-pair-indexes($admin-config, $database)
  for $expected in $db-config/db:geospatial-element-pair-indexes/db:geospatial-element-pair-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing geospatial element pair index: ", $expected/db:localname))
};

declare function setup:add-geospatial-element-child-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-child-indexes-R(
    $admin-config,
    $database,
    $db-config/db:geospatial-element-child-indexes/db:geospatial-element-child-index)
};

declare function setup:add-geospatial-element-child-indexes-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $index-configs as element(db:geospatial-element-child-index)*) as element(configuration)
{
  if ($index-configs) then
    setup:add-geospatial-element-child-indexes-R(
      admin:database-add-geospatial-element-child-index($admin-config, $database, $index-configs[1]),
      $database,
      fn:subsequence($index-configs, 2))
  else
    $admin-config
};

declare function setup:validate-geospatial-element-child-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-geospatial-element-child-indexes($admin-config, $database)
  for $expected in $db-config/db:geospatial-element-child-indexes/db:geospatial-element-child-index
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing geospatial element child index: ", $expected/db:localname))
};

declare function setup:add-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-word-lexicons-R(
    $admin-config,
    $database,
    $db-config/db:word-lexicons/db:word-lexicon)
};

declare function setup:add-word-lexicons-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $collations as xs:string*) as element(configuration)
{
  if ($collations) then
    setup:add-word-lexicons-R(
      setup:safe-database-add-word-lexicon($admin-config, $database, $collations[1]),
      $database,
      fn:subsequence($collations, 2))
  else
    $admin-config
};

declare function setup:validate-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-word-lexicons($admin-config, $database)
  for $expected in $db-config/db:word-lexicons/db:word-lexicon
  return
    if ($existing[$expected]) then ()
    else
      setup:validation-fail(fn:concat("Database missing word lexicon: ", $expected))
};


declare function setup:safe-database-add-word-lexicon(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $collation as xs:string) as element(configuration)
{
  admin:database-add-word-lexicon(
    $admin-config,
    $database,
    admin:database-word-lexicon($collation))
};

declare function setup:add-fragment-roots(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  (: remove any existing fragment roots first :)
  for $root in admin:database-get-fragment-roots($admin-config, $database)
  return
   xdmp:set($admin-config, admin:database-delete-fragment-root($admin-config, $database, $root)),

  setup:add-fragment-roots-R(
    $admin-config,
    $database,
    $db-config/db:fragment-roots/db:fragment-root)
};

declare function setup:add-fragment-roots-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $fragment-roots as element(db:fragment-root)*) as element(configuration)
{
  if ($fragment-roots) then
    setup:add-fragment-roots-R(
      admin:database-add-fragment-root(
        $admin-config,
        $database,
        admin:database-fragment-root(
          $fragment-roots[1]/db:namespace-uri,
          $fragment-roots[1]/db:localname)),
      $database,
      fn:subsequence($fragment-roots, 2))
  else
    $admin-config
};

declare function setup:validate-fragment-roots(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-fragment-roots($admin-config, $database)
  for $expected in $db-config/db:fragment-roots/db:fragment-root
  return
    if ($existing[db:namespace-uri = $expected/db:namespace-uri and db:localname = $expected/db:localname]) then ()
    else
      setup:validation-fail(fn:concat("Missing fragment root: ", $expected/db:localname))
};

declare function setup:add-fragment-parents(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  (: remove any existing fragment parents first :)
  for $parent in admin:database-get-fragment-parents($admin-config, $database)
  return
   xdmp:set($admin-config, admin:database-delete-fragment-parent($admin-config, $database, $parent)),

  setup:add-fragment-parents-R(
    $admin-config,
    $database,
    $db-config/db:fragment-parents/db:fragment-parent)
};

declare function setup:add-fragment-parents-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $fragment-parents as element(db:fragment-parent)*) as element(configuration)
{
  if ($fragment-parents) then
    setup:add-fragment-parents-R(
      admin:database-add-fragment-parent(
        $admin-config,
        $database,
        admin:database-fragment-parent(
          $fragment-parents[1]/db:namespace-uri,
          $fragment-parents[1]/db:localname)),
      $database,
      fn:subsequence($fragment-parents, 2))
  else
    $admin-config
};

declare function setup:validate-fragment-parents(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $existing := admin:database-get-fragment-parents($admin-config, $database)
  for $expected in $db-config/db:fragment-parents/db:fragment-parent
  return
    if ($existing[db:namespace-uri = $expected/db:namespace-uri and db:localname = $expected/db:localname]) then ()
    else
      setup:validation-fail(fn:concat("Missing fragment root: ", $expected/db:localname))
};

declare function setup:config-word-query(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  let $empty-field := $db-config/db:fields/db:field[db:field-name = ""]
  return
  (
    (: remove existing word query included elements first :)
    for $element in admin:database-get-word-query-included-elements($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-word-query-included-element(
          $admin-config,
          $database,
          $element)),

    (: now add the new ones :)
    for $element in $empty-field/db:included-elements/db:included-element
    return
      xdmp:set(
        $admin-config,
        admin:database-add-word-query-included-element(
          $admin-config,
          $database,
          $element)),

    (: remove existing word query excluded elements first :)
    for $element in admin:database-get-word-query-excluded-elements($admin-config, $database)
    return
      xdmp:set(
        $admin-config,
        admin:database-delete-word-query-excluded-element(
          $admin-config,
          $database,
          $element)),

    (: now add the new ones :)
    for $element in $empty-field/db:excluded-elements/db:excluded-element
    return
      xdmp:set(
        $admin-config,
        admin:database-add-word-query-excluded-element(
          $admin-config,
          $database,
          $element)),

    let $fast-case-sensitive-searches := $empty-field/db:fast-case-sensitive-searches
    where $fast-case-sensitive-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-fast-case-sensitive-searches(
          $admin-config,
          $database,
          $fast-case-sensitive-searches)),

    let $fast-diacritic-sensitive-searches := $empty-field/db:fast-diacritic-sensitive-searches
    where $fast-diacritic-sensitive-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-fast-diacritic-sensitive-searches(
          $admin-config,
          $database,
          $fast-diacritic-sensitive-searches)),

    let $fast-phrase-searches := $empty-field/db:fast-phrase-searches
    where $fast-phrase-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-fast-phrase-searches(
          $admin-config,
          $database,
          $fast-phrase-searches)),

    let $include-root := $empty-field/db:include-root
    where $include-root
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-include-document-root(
          $admin-config,
          $database,
          $include-root)),

    let $one-character-searches := $empty-field/db:one-character-searches
    where $one-character-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-one-character-searches(
          $admin-config,
          $database,
          $one-character-searches)),

    let $stemmed-searches := $empty-field/db:stemmed-searches
    where $stemmed-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-stemmed-searches(
          $admin-config,
          $database,
          $stemmed-searches)),

    let $three-character-searches := $empty-field/db:three-character-searches
    where $three-character-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-three-character-searches(
          $admin-config,
          $database,
          $three-character-searches)),

    let $three-character-word-positions := $empty-field/db:three-character-word-positions
    where $three-character-word-positions
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-three-character-word-positions(
          $admin-config,
          $database,
          $three-character-word-positions)),

    let $trailing-wildcard-searches := $empty-field/db:trailing-wildcard-searches
    where $trailing-wildcard-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-trailing-wildcard-searches(
          $admin-config,
          $database,
          $trailing-wildcard-searches)),

    let $trailing-wildcard-word-positions := $empty-field/db:trailing-wildcard-word-positions
    where $trailing-wildcard-word-positions
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-trailing-wildcard-word-positions(
          $admin-config,
          $database,
          $trailing-wildcard-word-positions)),

    let $two-character-searches := $empty-field/db:two-character-searches
    where $two-character-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-two-character-searches(
          $admin-config,
          $database,
          $two-character-searches)),

    let $word-searches := $empty-field/db:word-searches
    where $word-searches
    return
      xdmp:set(
        $admin-config,
        admin:database-set-word-query-word-searches(
          $admin-config,
          $database,
          $word-searches)),

    $admin-config
  )
};

declare function setup:validate-word-query(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database))
{
  let $empty-field := $db-config/db:fields/db:field[db:field-name = ""]
  return
  (
    let $existing := admin:database-get-word-query-included-elements($admin-config, $database)
    for $expected in $empty-field/db:included-elements/db:included-element
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Missing word query included element: ", $expected/db:localname)),

    let $existing := admin:database-get-word-query-excluded-elements($admin-config, $database)
    for $expected in $empty-field/db:excluded-elements/db:excluded-element
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Missing word query excluded element: ", $expected/db:localname)),

    let $actual := admin:database-get-word-query-fast-case-sensitive-searches($admin-config, $database)
    let $expected := $empty-field/db:fast-case-sensitive-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query fast case sensitive searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-fast-diacritic-sensitive-searches($admin-config, $database)
    let $expected := $empty-field/db:fast-diacritic-sensitive-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query fast diacritic sensitive searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-fast-phrase-searches($admin-config, $database)
    let $expected := $empty-field/db:fast-phrase-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query fast phrase searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-include-document-root($admin-config, $database)
    let $expected := $empty-field/db:include-root
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query include document root mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-one-character-searches($admin-config, $database)
    let $expected := $empty-field/db:one-character-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query one character searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-stemmed-searches($admin-config, $database)
    let $expected := $empty-field/db:stemmed-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query stemmed searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-three-character-searches($admin-config, $database)
    let $expected := $empty-field/db:three-character-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query three character searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-three-character-word-positions($admin-config, $database)
    let $expected := $empty-field/db:three-character-word-positions
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query three character word positions mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-trailing-wildcard-searches($admin-config, $database)
    let $expected := $empty-field/db:trailing-wildcard-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query trailing wildcard searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-trailing-wildcard-word-positions($admin-config, $database)
    let $expected := $empty-field/db:trailing-wildcard-word-positions
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query trailing wildcard word positions mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-two-character-searches($admin-config, $database)
    let $expected := $empty-field/db:two-character-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query two character searches mismatch! ", $expected, " != ", $actual)),

    let $actual := admin:database-get-word-query-word-searches($admin-config, $database)
    let $expected := $empty-field/db:word-searches
    where $expected
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("word query word searches mismatch! ", $expected, " != ", $actual))
  )
};

(:
  if the triggers database is 0, set it to 0.
  if the triggers database is set to an ID of another database in the import,
  get its new ID and set it to that
:)
declare function setup:set-triggers-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  let $triggers-database-id :=
    if ($db-config/db:triggers-database/@name) then
      xdmp:database($db-config/db:triggers-database/@name)
    else
      0
  return
    admin:database-set-triggers-database(
      $admin-config,
      $database,
      $triggers-database-id)
};

declare function setup:validate-triggers-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-triggers-database($admin-config, $database)
  let $expected :=
    if ($db-config/db:triggers-database/@name) then
      xdmp:database($db-config/db:triggers-database/@name)
    else
      0
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Triggers database mismatch! ", $expected, " != ", $actual))
};


(:
  if the schema database is 0, set it to 0.
  if the schema database is set to an ID of another database in the import,
  get its new ID and set it to that
:)
declare function setup:set-schema-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  let $schema-database-id :=
    if ($db-config/db:schema-database/@name) then
      xdmp:database($db-config/db:schema-database/@name)
    else
      $default-schemas
  return
    admin:database-set-schema-database(
      $admin-config,
      $database,
      $schema-database-id)
};

declare function setup:validate-schema-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-schema-database($admin-config, $database)
  let $expected :=
    if ($db-config/db:schema-database/@name) then
      xdmp:database($db-config/db:schema-database/@name)
    else
      $default-schemas
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Schema database mismatch! ", $expected, " != ", $actual))
};

(:
  if the security database is 0, set it to 0.
  if the security database is set to an ID of another database in the import,
  get its new ID and set it to that
:)
declare function setup:set-security-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  let $security-database-id :=
    if ($db-config/db:security-database/@name) then
      xdmp:database($db-config/db:security-database/@name)
    else
      $default-security
  return
    admin:database-set-security-database(
      $admin-config,
      $database,
      $security-database-id)
};

declare function setup:validate-security-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-security-database($admin-config, $database)
  let $expected :=
    if ($db-config/db:security-database/@name) then
      xdmp:database($db-config/db:security-database/@name)
    else
      $default-security
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Security database mismatch! ", $expected, " != ", $actual))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of app servers
 ::)

declare function setup:create-appservers(
  $import-config as element(configuration)) as item()*
{
  for $http-config in $import-config//gr:http-servers/gr:http-server
  return
    setup:create-appserver($http-config),

  for $xdbc-config in $import-config//gr:xdbc-servers/gr:xdbc-server
  return
    setup:create-xdbcserver($xdbc-config)
};

declare function setup:validate-appservers(
  $import-config as element(configuration)) as item()*
{
  for $http-config in $import-config//gr:http-servers/gr:http-server
  return
    setup:validate-appserver($http-config),

  for $xdbc-config in $import-config//gr:xdbc-servers/gr:xdbc-server
  return
    setup:validate-xdbcserver($xdbc-config)
};

declare function setup:create-appserver(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(.) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then
      fn:concat("HTTP Server ", $server-name, " already exists, not recreated..")
    else
      let $root := $server-config/gr:root[fn:string-length(.) > 0]
      let $root := if ($root) then $root else "/"
      let $port := xs:unsignedLong($server-config/gr:port)
      let $is-webdav := xs:boolean($server-config/gr:webDAV)
      let $database-id :=
        if ($server-config/gr:database/@name) then
          xdmp:database($server-config/gr:database/@name)
        else
          0
      let $modules-id :=
        if ($server-config/gr:modules/@name eq "filesystem") then
          0
        else if ($server-config/gr:modules/@name) then
          xdmp:database($server-config/gr:modules/@name)
        else
          0

      let $admin-config := admin:get-configuration()
      let $admin-config :=
        if ($is-webdav) then
          (: Note: database id is stored as modules is for webdav servers :)
          admin:webdav-server-create(
            $admin-config,
            $default-group,
            $server-name,
            $root,
            $port,
            $modules-id)
        else
          admin:http-server-create(
            $admin-config,
            $default-group,
            $server-name,
            $root,
            $port,
            $modules-id,
            $database-id)
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        fn:concat("HTTP Server ", $server-name, " succesfully created.")
      )
};

declare function setup:validate-appserver(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(.) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing HTTP server: ", $server-name))
};

declare function setup:create-xdbcserver(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(.) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then
      fn:concat("XDBC Server ", $server-name, " already exists, not recreated..")
    else
      let $root := $server-config/gr:root[fn:string-length(.) > 0]
      let $root := if ($root) then $root else "/"
      let $port := xs:unsignedLong($server-config/gr:port)
      let $database-id :=
        if ($server-config/gr:database/@name) then
          xdmp:database($server-config/gr:database/@name)
        else
          0
      let $modules-id :=
        if ($server-config/gr:modules/@name eq "filesystem") then
          0
        else if ($server-config/gr:modules/@name) then
          xdmp:database($server-config/gr:modules/@name)
        else
          0

      let $admin-config := admin:get-configuration()
      let $admin-config :=
        admin:xdbc-server-create(
          $admin-config,
          $default-group,
          $server-name,
          $root,
          $port,
          $modules-id,
          $database-id)
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        fn:concat("XDBC Server ", $server-name, " succesfully created.")
      )
};

declare function setup:validate-xdbcserver(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(.) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing XDBC server: ", $server-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Configuration of app servers
 ::)

declare function setup:apply-appservers-settings(
  $import-config as element(configuration)) as item()*
{
  for $http-config in $import-config//gr:http-servers/gr:http-server
  return
    setup:configure-http-server($http-config),

  for $xdbc-config in $import-config//gr:xdbc-servers/gr:xdbc-server
  return
    setup:configure-xdbc-server($xdbc-config),

  for $task-config in $import-config/gr:task-server
  return
    setup:configure-task-server($task-config)
};

declare function setup:validate-appservers-settings(
  $import-config as element(configuration)) as item()*
{
  for $http-config in $import-config//gr:http-servers/gr:http-server
  return
    setup:validate-http-server($http-config),

  for $xdbc-config in $import-config//gr:xdbc-servers/gr:xdbc-server
  return
    setup:validate-xdbc-server($xdbc-config),

  for $task-config in $import-config/gr:task-server
  return
    setup:validate-task-server($task-config)
};

declare function setup:configure-http-server(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(.) > 0]
  let $server-id := xdmp:server($server-name)
  let $admin-config := setup:configure-server($server-config, $server-id)
  return
  (
    if (xdmp:eval('
    import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
    import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

    declare namespace gr="http://marklogic.com/xdmp/group";
    declare namespace err="http://marklogic.com/xdmp/error";

    declare variable $server-config as element() external;
    declare variable $server-name as xs:string external;
    declare variable $admin-config as element() external;
    declare variable $server-id external;
    declare variable $default-user external;

    let $default-user :=
      if ($server-config/gr:default-user/@name) then
        xdmp:user($server-config/gr:default-user/@name)
      else
        $default-user
    let $is-webdav := xs:boolean($server-config/gr:webDAV)

    (: reconnect databases in case the appserver already existed :)
    let $database-id :=
      if ($server-config/gr:database/@name) then
        xdmp:database($server-config/gr:database/@name)
      else
        0
    let $modules-id :=
      if ($server-config/gr:modules/@name eq "filesystem") then
        0
      else if ($server-config/gr:modules/@name) then
        xdmp:database($server-config/gr:modules/@name)
      else
        0
    let $root := $server-config/gr:root[fn:string-length(.) > 0]
    let $root := if ($root) then $root else "/"

    let $admin-config :=
      if ($is-webdav) then
        admin:appserver-set-database($admin-config, $server-id, $modules-id)
      else
        admin:appserver-set-database($admin-config, $server-id, $database-id)
    let $admin-config :=
      if ($is-webdav) then
        $admin-config
      else
        admin:appserver-set-modules-database($admin-config, $server-id, $modules-id)

    let $admin-config := admin:appserver-set-root($admin-config, $server-id, $root)

    let $value := $server-config/gr:session-timeout[fn:string-length(.) > 0]
    let $admin-config :=
      if ($value) then
        admin:appserver-set-session-timeout($admin-config, $server-id, $value)
      else
        $admin-config

    let $value := $server-config/gr:static-expires[fn:string-length(.) > 0]
    let $admin-config :=
      if ($value) then
        admin:appserver-set-static-expires($admin-config, $server-id, $value)
      else
        $admin-config

    let $admin-config :=
      admin:appserver-set-default-user($admin-config, $server-id, $default-user)

    let $admin-config :=
      if ($is-webdav) then
        let $value := $server-config/gr:compute-content-length[fn:string-length(.) > 0]
        return
          if ($value) then
            admin:appserver-set-compute-content-length($admin-config, $server-id, $value)
          else
            $admin-config
      else
        let $value := $server-config/gr:error-handler[fn:string-length(.) > 0]
        let $admin-config :=
          if ($value) then
            admin:appserver-set-error-handler($admin-config, $server-id, $value)
          else
            $admin-config

        let $value := $server-config/gr:url-rewriter[fn:string-length(.) > 0]
        let $admin-config :=
          if ($value) then
            admin:appserver-set-url-rewriter($admin-config, $server-id, $value)
          else
            $admin-config

        return $admin-config

    (: TODO ?
    <ssl-certificate-template>0</ssl-certificate-template>
    <ssl-allow-sslv3>true</ssl-allow-sslv3>
    <ssl-allow-tls>true</ssl-allow-tls>
    <ssl-hostname />
    <ssl-ciphers>ALL:!LOW:@STRENGTH</ssl-ciphers>
    <ssl-require-client-certificate>true</ssl-require-client-certificate>
    <ssl-client-certificate-authorities />
    :)

    return
      admin:save-configuration-without-restart($admin-config)',
    (xs:QName("server-config"), $server-config,
     xs:QName("server-name"), $server-name,
     xs:QName("admin-config"), $admin-config,
     xs:QName("server-id"), $server-id,
     xs:QName("default-user"), $default-user))) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("HTTP Server ", $server-name, " settings applied succesfully.")
  )
};

declare function setup:validate-http-server(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(.) > 0]
  let $server-id := xdmp:server($server-name)
  let $admin-config := admin:get-configuration()
  let $default-user :=
    if ($server-config/gr:default-user/@name) then
      xdmp:user($server-config/gr:default-user/@name)
    else
      $default-user
  let $is-webdav := xs:boolean($server-config/gr:webDAV)

  (: reconnect databases in case the appserver already existed :)
  let $database-id :=
    if ($server-config/gr:database/@name) then
      xdmp:database($server-config/gr:database/@name)
    else
      0
  let $modules-id :=
    if ($server-config/gr:modules/@name eq "filesystem") then
      0
    else if ($server-config/gr:modules/@name) then
      xdmp:database($server-config/gr:modules/@name)
    else
      0
  let $root := $server-config/gr:root[fn:string-length(.) > 0]
  let $root := if ($root) then $root else "/"

  return
  (
    setup:validate-server($server-config, $server-id),

    let $actual := admin:appserver-get-database($admin-config, $server-id)
    return
      if ($is-webdav) then
        if ($modules-id = $actual) then ()
        else
          setup:validation-fail(fn:concat("Invalid Appserver database: ", $modules-id, " != ", $actual))
      else
      (
        if ($database-id = $actual) then ()
        else
          setup:validation-fail(fn:concat("Invalid Appserver database: ", $database-id, " != ", $actual)),

        let $actual := admin:appserver-get-modules-database($admin-config, $server-id)
        return
          if ($actual = $modules-id) then ()
          else
            setup:validation-fail(fn:concat("Invalid Appserver modules database: ", $modules-id, " != ", $actual))
      ),

    let $actual := admin:appserver-get-root($admin-config, $server-id)
    return
      if ($root = $actual) then ()
      else
        setup:validation-fail(fn:concat("Appserver root mismatch: ", $root, " != ", $actual)),

    let $expected := $server-config/gr:session-timeout[fn:string-length(.) > 0]
    let $actual := admin:appserver-get-session-timeout($admin-config, $server-id)
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("Appserver session timeout mismatch: ", $expected, " != ", $actual)),

    let $expected := $server-config/gr:static-expires[fn:string-length(.) > 0]
    let $actual := admin:appserver-get-static-expires($admin-config, $server-id)
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("Appserver static expires mismatch: ", $expected, " != ", $actual)),

    let $actual := admin:appserver-get-default-user($admin-config, $server-id)
    return
      if ($default-user = $actual) then ()
      else
        setup:validation-fail(fn:concat("Appserver default user mismatch: ", $default-user, " != ", $actual)),

    if ($is-webdav) then
      let $expected := $server-config/gr:compute-content-length[fn:string-length(.) > 0]
      let $actual := admin:appserver-get-compute-content-length($admin-config, $server-id)
      return
        if ($expected = $actual) then ()
        else
          setup:validation-fail(fn:concat("Appserver compute content length mismatch: ", $expected, " != ", $actual))
    else
    (
      let $expected := $server-config/gr:error-handler[fn:string-length(.) > 0]
      let $actual := admin:appserver-get-error-handler($admin-config, $server-id)
      return
        if ($expected = $actual) then ()
        else
          setup:validation-fail(fn:concat("Appserver error handler mismatch: ", $expected, " != ", $actual)),

      let $expected := $server-config/gr:url-rewriter[fn:string-length(.) > 0]
      let $actual := admin:appserver-get-url-rewriter($admin-config, $server-id)
      return
        if ($expected = $actual) then ()
        else
          setup:validation-fail(fn:concat("Appserver url rewriter mismatch: ", $expected, " != ", $actual))
    )
  )
};

declare function setup:configure-xdbc-server(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(.) > 0]
  return
    (: reconnect databases in case the appserver already existed :)
    let $database-id :=
      if ($server-config/gr:database/@name) then
        xdmp:database($server-config/gr:database/@name)
      else
        0
    let $modules-id :=
      if ($server-config/gr:modules/@name eq "filesystem") then
        0
      else if ($server-config/gr:modules/@name) then
        xdmp:database($server-config/gr:modules/@name)
      else
        0
    let $server-id := xdmp:server($server-name)
    let $admin-config :=
      admin:appserver-set-modules-database(
        admin:appserver-set-database(
          setup:configure-server($server-config, $server-id),
          $server-id,
          $database-id),
        $server-id,
        $modules-id)
    return
    (
      if (admin:save-configuration-without-restart($admin-config)) then
        xdmp:set($restart-needed, fn:true())
      else (),
      fn:concat("XDBC Server ", $server-name, " settings applied succesfully.")
    )
};

declare function setup:validate-xdbc-server(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-id := xdmp:server($server-config/gr:xdbc-server-name[fn:string-length(.) > 0])
  let $admin-config := admin:get-configuration()
  return
  (
    setup:validate-server($server-config, $server-id),

    let $expected := ($server-config/gr:database/@name/xdmp:database(.), 0)[1]
    let $actual := admin:appserver-get-database($admin-config, $server-id)
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("XDBC Server database mismatch: ", $expected, " != ", $actual)),

    let $expected :=
      if ($server-config/gr:modules/@name eq "filesystem") then
        0
      else if ($server-config/gr:modules/@name) then
        xdmp:database($server-config/gr:modules/@name)
      else
        0
    let $actual := admin:appserver-get-modules-database($admin-config, $server-id)
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("XDBC Server modules database mismatch: ", $expected, " != ", $actual))
  )
};

declare function setup:configure-task-server(
  $server-config as element(gr:task-server)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $settings :=
    <settings>
      <setting>debug-allow</setting>
      <setting>debug-threads</setting>
      <setting>default-time-limit</setting>
      <setting>log-errors</setting>
      <setting>max-time-limit</setting>
      <setting>post-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-limit</setting>
      <setting>profile-allow</setting>
      <setting>queue-size</setting>
      <setting>threads</setting>
    </settings>
  let $apply-settings :=
    for $setting in $settings/*:setting
    let $value := fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting)))
    where fn:exists($value)
    return
      xdmp:set($admin-config, xdmp:value(fn:concat("admin:taskserver-set-", $setting, "($admin-config, $default-group, $value)")))
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("Task Server settings applied succesfully.")
  )
};

declare function setup:validate-task-server(
  $server-config as element(gr:task-server)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $settings :=
    <settings>
      <setting>debug-allow</setting>
      <setting>debug-threads</setting>
      <setting>default-time-limit</setting>
      <setting>log-errors</setting>
      <setting>max-time-limit</setting>
      <setting>post-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-limit</setting>
      <setting>profile-allow</setting>
      <setting>queue-size</setting>
      <setting>threads</setting>
    </settings>
  for $setting in $settings/*:setting
  let $expected := fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting)))
  let $actual := xdmp:value(fn:concat("admin:taskserver-get-", $setting, "($admin-config, $default-group)"))
  where fn:exists($expected)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Task Server ", $setting, " mismatch: ", $expected, " != ", $actual))
};

declare function setup:configure-server(
  $server-config as element(),
  $server-id as xs:unsignedLong) as element(configuration)
{
  let $admin-config := admin:get-configuration()
  let $settings :=
    <settings>
      <setting value="($server-config/gr:last-login/@name/xdmp:database(.), 0)[1]" path="/@name">last-login</setting>
      <setting>display-last-login</setting>
      <setting>backlog</setting>
      <setting>threads</setting>
      <setting>request-timeout</setting>
      <setting>keep-alive-timeout</setting>
      <setting>max-time-limit</setting>
      <setting>default-time-limit</setting>
      <setting>pre-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-limit</setting>
      <setting>collation</setting>
      <setting>authentication</setting>
      <setting>concurrent-request-limit</setting>
      <setting>log-errors</setting>
      <setting>debug-allow</setting>
      <setting>profile-allow</setting>
      <setting>default-xquery-version</setting>
      <setting>output-sgml-character-entities</setting>
      <setting>output-encoding</setting>
    </settings>
  let $apply-settings :=
    for $setting in $settings/*:setting
    let $value :=
      if ($setting/@value) then
        fn:data(xdmp:value($setting/@value))
      else
        fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting, "[fn:string-length(.) > 0]")))
    where (fn:exists($value))
    return
      xdmp:set($admin-config,
        xdmp:value(fn:concat("admin:appserver-set-", $setting, "($admin-config, $server-id, $value)")))

  let $namespaces := $server-config/gr:namespaces/gr:namespace
  let $admin-config :=
    if ($namespaces) then
      let $old-ns := admin:appserver-get-namespaces($admin-config, $server-id)
      let $config :=
        (: First delete any namespace that matches the prefix and uri :)
        admin:appserver-delete-namespace(
          $admin-config,
          $server-id,
          for $ns in $namespaces
          let $same-prefix :=
            $old-ns[gr:prefix = $ns/gr:prefix][gr:namespace-uri ne $ns/gr:namespace-uri]
          return
            if ($same-prefix) then
              admin:group-namespace($same-prefix/gr:prefix, $same-prefix/gr:namespace-uri)
            else ())
      return
      (: Then add in any namespace whose prefix isn't already defined :)
        admin:appserver-add-namespace(
          $config,
          $server-id,
          for $ns in $namespaces
          return
            if ($old-ns[gr:prefix = $ns/gr:prefix][gr:namespace-uri = $ns/gr:namespace-uri]) then ()
            else
              admin:group-namespace($ns/gr:prefix, $ns/gr:namespace-uri))
    else
      $admin-config
  (: TODO: schemas, request-blackouts :)
  return
    $admin-config
};

declare function setup:validate-server(
  $server-config as element(),
  $server-id as xs:unsignedLong) as element(configuration)
{
  let $admin-config := admin:get-configuration()
  let $_ :=
    let $actual := admin:appserver-get-last-login($admin-config, $server-id)
    let $expected :=
      if ($server-config/gr:last-login/@name) then
        xdmp:database($server-config/gr:last-login/@name)
      else 0
    return
      if ($actual = $expected) then ()
      else
        setup:validation-fail(fn:concat("Appserver last-login mismatch: ", $expected, " != ", $actual))
  let $settings :=
    <settings>
      <setting>display-last-login</setting>
      <setting>backlog</setting>
      <setting>threads</setting>
      <setting>request-timeout</setting>
      <setting>keep-alive-timeout</setting>
      <setting>max-time-limit</setting>
      <setting>default-time-limit</setting>
      <setting>pre-commit-trigger-depth</setting>
      <setting>pre-commit-trigger-limit</setting>
      <setting>collation</setting>
      <setting>authentication</setting>
      <setting>concurrent-request-limit</setting>
      <setting>log-errors</setting>
      <setting>debug-allow</setting>
      <setting>profile-allow</setting>
      <setting>default-xquery-version</setting>
      <setting>output-sgml-character-entities</setting>
      <setting>output-encoding</setting>
    </settings>
  for $setting in $settings/*:setting
  let $expected := fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting, "[fn:string-length(.) > 0]")))
  let $actual := xdmp:value(fn:concat("admin:appserver-get-", $setting, "($admin-config, $server-id)"))
  where $expected
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Appserver ", $setting, " mismatch: ", $expected, " != ", $actual)),

  let $admin-config := admin:get-configuration()
  let $existing := admin:appserver-get-namespaces($admin-config, $server-id)
  for $expected in $server-config/gr:namespaces/gr:namespace
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Appserver missing namespace: ", $expected/gr:namespace-uri))
};

declare function setup:create-privileges(
  $import-config as element(configuration))
{
  for $privilege in $import-config/sec:privileges/sec:privilege
  let $privilege-name as xs:string := $privilege/sec:privilege-name
  let $action as xs:string? := $privilege/sec:action
  let $kind as xs:string := $privilege/sec:kind
  let $role-names as xs:string* := ()
  let $match := setup:get-privileges()/sec:privilege[sec:privilege-name = $privilege-name]
  return
    if ($match) then
      if ($match/sec:action != $action or $match/sec:kind != $kind) then
        fn:error(
          xs:QName("PRIV-MISMATCH"),
          fn:concat(
            "Configured privilege conflicts with existing one: name=",
            $privilege-name,
            "; action=", $action, "; kind=",
            $kind)
        )
      else () (: It's a match. No need to mess with it. :)
    else
    (
      (: Create this new privilege :)
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $privilege-name as xs:string external;
         declare variable $action as xs:string external;
         declare variable $kind as xs:string external;
         declare variable $role-names as element() external;
         sec:create-privilege($privilege-name, $action, $kind, $role-names/*)',
        (xs:QName("privilege-name"), $privilege-name,
         xs:QName("action"), $action,
         xs:QName("kind"), $kind,
         xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
        <options xmlns="xdmp:eval">
          <database>{$default-security}</database>
        </options>),
      setup:add-rollback("privileges", $privilege)
    )
};

declare function setup:validate-privileges(
  $import-config as element(configuration))
{
  for $privilege in $import-config/sec:privileges/sec:privilege
  let $privilege-name as xs:string := $privilege/sec:privilege-name
  let $action as xs:string? := $privilege/sec:action
  let $kind as xs:string := $privilege/sec:kind
  let $match := setup:get-privileges()/sec:privilege[sec:privilege-name = $privilege-name]
  return
    if ($match) then
      if ($match/sec:action != $action or $match/sec:kind != $kind) then
        setup:validation-fail(
          fn:concat(
            "Privilege mismatch: name=",
            $privilege-name,
            "; action=", $action, "; kind=",
            $kind))
      else () (: It's a match. :)
    else
      setup:validation-fail(fn:concat("Missing privilege: ", $privilege-name))
};

declare function setup:create-roles(
  $import-config as element(configuration))
{
  for $role in $import-config//sec:roles/sec:role
  let $role-name as xs:string := $role/sec:role-name
  let $description as xs:string? := $role/sec:description
  let $role-names as xs:string* := $role/sec:role-names/sec:role-name
  let $permissions as element(sec:permission)* := $role/sec:permissions/*
  let $collections as xs:string* := $role/sec:collections/*
  let $privileges as element(sec:privilege)* := $role/sec:privileges/*
  let $amps as element(sec:amp)* := $role/sec:amps/*
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>
  return
    (: if the role exists, then update it :)
    if (setup:get-roles(())/sec:role[sec:role-name = $role-name]) then
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $role-name as xs:string external;
         declare variable $description as xs:string external;
         sec:role-set-description($role-name, $description)',
        (xs:QName("role-name"), $role-name,
         xs:QName("description"), fn:string($description)),
        $eval-options),
      if ($role-names) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $role-name as xs:string external;
           declare variable $role-names as element() external;
           sec:role-set-roles($role-name, $role-names/*)',
          (xs:QName("role-name"), $role-name,
           xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
          $eval-options)
      else (),

      if ($permissions) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $role-name as xs:string external;
           declare variable $permissions as element() external;
           sec:role-set-default-permissions($role-name, $permissions/*)',
          (
            xs:QName("role-name"), $role-name,
            xs:QName("permissions"),
            <w>
            {
              for $p in $permissions
              return
                xdmp:permission($p/sec:role-name, $p/sec:capability)
            }
            </w>
          ),
          $eval-options)
      else (),

      if ($collections) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $role-name as xs:string external;
           declare variable $collections as element() external;
           sec:role-set-default-collections($role-name, $collections/*)',
          (xs:QName("role-name"), $role-name,
           xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
          $eval-options)
      else (),

      for $privilege in $privileges
      let $priv := setup:get-privilege-by-name($privilege/sec:privilege-name)
      return
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $action as xs:string external;
           declare variable $kind as xs:string external;
           declare variable $role-name as xs:string external;
           sec:privilege-add-roles($action, $kind, $role-name)',
          (xs:QName("action"), $priv/sec:action,
           xs:QName("kind"), $priv/sec:kind,
           xs:QName("role-name"), $role-name),
          $eval-options),

      for $amp in $amps
      return
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $namespace as xs:string external;
           declare variable $local-name as xs:string external;
           declare variable $document-uri as xs:string external;
           declare variable $database as xs:unsignedLong external;
           declare variable $role-name as xs:string external;
           sec:amp-add-roles($namespace, $local-name, $document-uri, $database, $role-name)',
          (xs:QName("namespace"), $amp/sec:namespace,
           xs:QName("local-name"), $amp/sec:local-name,
           xs:QName("document-uri"), $amp/sec:document-uri,
           xs:QName("database"), if ($amp/sec:database-name eq "filesystem") then 0 else xdmp:database($amp/sec:database-name),
           xs:QName("role-name"), $role-name),
          $eval-options)
    )
    (: role is new. create it :)
    else
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $role-name as xs:string external;
         declare variable $description as xs:string external;
         declare variable $collections as element() external;
         sec:create-role($role-name, $description, (), (), $collections/*)',
        (xs:QName("role-name"), $role-name,
         xs:QName("description"), fn:string($description),
         xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
        $eval-options),
      setup:add-rollback("roles", $role)
    )
};

declare function setup:validate-roles(
  $import-config as element(configuration))
{
  for $role in $import-config//sec:roles/sec:role
  let $role-name as xs:string := $role/sec:role-name
  let $description as xs:string? := $role/sec:description
  let $role-names as xs:string* := $role/sec:role-names/sec:role-name
  let $permissions as element(sec:permission)* := $role/sec:permissions/*
  let $collections as xs:string* := $role/sec:collections/*
  let $privileges as element(sec:privilege)* := $role/sec:privileges/*
  let $amps as element(sec:amp)* := $role/sec:amps/*
  let $match := setup:get-roles(())/sec:role[sec:role-name = $role-name]
  return
    (: if the role exists, then update it :)
    if ($match) then
      if ($match/sec:role-name != $role-name or
          $match/sec:description != $description or
          $match/sec:role-names/sec:role-name != $role-names) then
        setup:validation-fail(fn:concat("Mismatched role: ", $role-name))
      else ()
    else
      setup:validation-fail(fn:concat("Missing role: ", $role-name))
};

declare function setup:create-users($import-config as element(configuration))
{
  for $user in $import-config//sec:users/sec:user
  let $user-name as xs:string := $user/sec:user-name
  let $description as xs:string? := $user/sec:description
  let $password as xs:string := $user/sec:password
  let $role-names as xs:string* := $user/sec:role-names/*
  let $permissions as element(sec:permission)* := $user/sec:permissions/*
  let $collections as xs:string* := $user/sec:collections/*
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>
  return
    if (setup:get-users(())/sec:user[sec:user-name = $user-name]) then
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $user-name as xs:string external;
         declare variable $description as xs:string external;
         sec:user-set-description($user-name, $description)',
        (xs:QName("user-name"), $user-name,
         xs:QName("description"), fn:string($description)),
        $eval-options),

      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $user-name as xs:string external;
         declare variable $password as xs:string external;
         sec:user-set-password($user-name, $password)',
        (xs:QName("user-name"), $user-name,
         xs:QName("password"), fn:string($password)),
        $eval-options),

      if ($role-names) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $user-name as xs:string external;
           declare variable $role-names as element() external;
           sec:user-set-roles($user-name, $role-names/*)',
          (xs:QName("user-name"), $user-name,
           xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
          $eval-options)
      else (),

      if ($permissions) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $user-name as xs:string external;
           declare variable $permissions as element() external;
           sec:user-set-default-permissions($user-name, $permissions/*)',
          (xs:QName("user-name"), $user-name,
           xs:QName("permissions"), <w>{for $p in $permissions return xdmp:permission($p/sec:role-name, $p/sec:capability)}</w>),
          $eval-options)
      else (),

      if ($collections) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $user-name as xs:string external;
           declare variable $collections as element() external;
           sec:user-set-default-collections($user-name, $collections/*)',
          (xs:QName("user-name"), $user-name,
           xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
          $eval-options)
      else ()
    )
    else
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $user-name as xs:string external;
         declare variable $description as xs:string external;
         declare variable $password as xs:string external;
         declare variable $role-names as element() external;
         declare variable $permissions as element() external;
         declare variable $collections as element() external;
         sec:create-user($user-name, $description, $password, $role-names/*, $permissions/*, $collections/*)',
        (xs:QName("user-name"), $user-name,
         xs:QName("description"), fn:string($description),
         xs:QName("password"), $password,
         xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>,
         xs:QName("permissions"), <w/>,
         xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
        $eval-options),
      setup:add-rollback("users", $user),
      if ($permissions) then
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $user-name as xs:string external;
           declare variable $permissions as element() external;
           sec:user-set-default-permissions($user-name, for $p in $permissions/* return xdmp:permission($p/sec:role-name, $p/sec:capability))',
          (xs:QName("user-name"), $user-name,
           xs:QName("permissions"), <w>{$permissions}</w>),
          $eval-options)
      else ()
    )
};

declare function setup:validate-users($import-config as element(configuration))
{
  for $user in $import-config//sec:users/sec:user
  let $user-name as xs:string := $user/sec:user-name
  let $description as xs:string? := $user/sec:description
  let $password as xs:string := $user/sec:password
  let $role-names as xs:string* := $user/sec:role-names/*
  let $permissions as element(sec:permission)* := $user/sec:permissions/*
  let $collections as xs:string* := $user/sec:collections/*
  let $match := setup:get-users(())/sec:user[sec:user-name = $user-name]
  return
    if ($match) then
      if ($match/sec:description != $description or
          $match/sec:role-names/* != $role-names) then
        setup:validation-fail(fn:concat("User mismatch: ", $user-name))
      else ()
    else
      setup:validation-fail(fn:concat("Missing user: ", $user-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 ::
 ::)
declare function setup:create-amps($import-config)
{
  let $existing-amps := setup:get-amps(())
  for $amp in $import-config/sec:amps/sec:amp
  return
    if ($existing-amps/sec:amp[sec:namespace = $amp/sec:namespace and
                                   sec:local-name = $amp/sec:local-name and
                                   sec:document-uri = $amp/sec:doc-uri and
                                   sec:db-name = $amp/sec:db-name]) then ()
    else
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $amp external;
         sec:create-amp(
           $amp/sec:namespace,
           $amp/sec:local-name,
           $amp/sec:doc-uri,
           xdmp:database($amp/sec:db-name),
           $amp/sec:role-name
        )',
        (xs:QName("amp"), $amp),
        <options xmlns="xdmp:eval">
          <database>{xdmp:security-database()}</database>
        </options>
      ),
      setup:add-rollback("amps", $amp)
    )
};

declare function setup:validate-amps($import-config)
{
  let $existing-amps := setup:get-amps(())
  for $amp in $import-config/sec:amps/sec:amp
  return
    if ($existing-amps/sec:amp[sec:namespace = $amp/sec:namespace and
                                   sec:local-name = $amp/sec:local-name and
                                   sec:document-uri = $amp/sec:doc-uri and
                                   sec:db-name = $amp/sec:db-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing amp: ", $amp/sec:local-name))
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Export configuration to XML
 ::)
declare function setup:get-configuration(
  $databases as xs:string*,
  $forests as xs:string*,
  $app-servers as xs:string*,
  $user-ids as xs:unsignedLong*,
  $role-ids as xs:unsignedLong*,
  $mimetypes as xs:string*) as element()
{
  <configuration>
    {setup:get-app-servers($app-servers)}
    {setup:get-forests($forests)}
    {setup:get-databases($databases)}
    {setup:get-users($user-ids)}
    {setup:get-roles($role-ids)}
    {setup:get-mimetypes($mimetypes)}
  </configuration>
};

declare function setup:get-app-servers($names as xs:string*) as element()*
{
  let $groups := setup:read-config-file("groups.xml")/gr:groups/gr:group
  return (
    let $http-servers := $groups/gr:http-servers/gr:http-server[gr:http-server-name = $names]
    where $http-servers
    return
      <http-servers xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://marklogic.com/xdmp/group">
        {
          for $http-server in $http-servers
          return
            setup:resolve-ids-to-names(
              setup:strip-default-properties-from-http-server(
                $http-server
              )
            )
        }
      </http-servers>,

    let $xdbc-servers := $groups/gr:xdbc-servers/gr:xdbc-server[gr:xdbc-server-name = $names]
    where $xdbc-servers
    return
      <xdbc-servers xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://marklogic.com/xdmp/group">
        {
          for $xdbc-server in $xdbc-servers
          return
            setup:resolve-ids-to-names(
              setup:strip-default-properties-from-xdbc-server(
                $xdbc-server
              )
            )
        }
      </xdbc-servers>
  )
};

declare function setup:get-forests($names as xs:string*) as element(as:assignments) {
  let $forests := setup:read-config-file("assignments.xml")/as:assignments
  let $forests := $forests/as:assignment[as:forest-name = $names]
  where $forests
  return
    <assignments xsi:schemaLocation="http://marklogic.com/xdmp/assignments assignments.xsd"
           xmlns="http://marklogic.com/xdmp/assignments"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      {
        for $forest in $forests
        return
          setup:resolve-ids-to-names(
            setup:strip-default-properties-from-forest(
              $forest
            )
          )
      }
    </assignments>
};

declare function setup:get-databases($names as xs:string*) as element(db:databases) {
  let $databases := setup:read-config-file("databases.xml")/db:databases
  let $databases := $databases/db:database[db:database-name = $names]
  where $databases
  return
    <databases xsi:schemaLocation="http://marklogic.com/xdmp/database database.xsd"
           xmlns="http://marklogic.com/xdmp/database"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      {
        for $database in $databases
        return
          setup:resolve-ids-to-names(
            setup:strip-default-properties-from-database(
              $database
            )
          )
      }
    </databases>
};

declare function setup:get-role-name($id as xs:unsignedLong) as xs:string? {
  xdmp:eval(
    'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
     declare variable $id as xs:unsignedLong external;
     sec:get-role-names($id)',
     (xs:QName("id"), $id),
     <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>)
};

declare function setup:get-role-privileges($role as element(sec:role)) as element(sec:privilege)* {
  xdmp:eval(
    'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
     declare variable $role-name as xs:string external;
     sec:role-privileges($role-name)',
    (xs:QName("role-name"), fn:string($role/sec:role-name)),
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>)[sec:role-ids/sec:role-id = $role/sec:role-id]
};

declare function setup:get-privileges() as element(sec:privileges)? {
  <privileges xmlns="http://marklogic.com/xdmp/security">
  {
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       /sec:privilege',
      (),
      <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
      </options>)
  }
  </privileges>
};

declare function setup:get-privilege-by-name($name as xs:string) as element(sec:privilege)? {
  xdmp:eval(
    'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
     declare variable $name external;
     /sec:privilege[sec:privilege-name = $name]',
    (xs:QName("name"), $name),
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>)
};

declare function setup:get-users($ids as xs:unsignedLong*) as element(sec:users)? {
  let $users :=
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       /sec:user',
       (),
       <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
       </options>)
  let $users :=
    if ($ids) then
      $users[sec:user-id = $ids]
    else
      $users
  where $users
  return
    <users xmlns="http://marklogic.com/xdmp/security">
    {
      for $user in $users
      return
        element sec:user
        {
          $user/@*,
          $user/*[fn:not(self::sec:user-id) and
                  fn:not(self::sec:digest-password) and
                  fn:not(self::sec:password) and
                  fn:not(self::sec:role-ids) and
                  fn:not(self::sec:permissions)],

          element sec:password {()},

          element sec:role-names
          {
            for $id in $user/sec:role-ids/*
            return
              element sec:role-name {setup:get-role-name($id)}
          },

          element sec:permissions
          {
            for $perm in $user/sec:permissions/sec:permission
            return
              element sec:permission
              {
                $perm/sec:capability,
                element sec:role-name {setup:get-role-name($perm/sec:role-id)}
              }
          }
        }
    }
    </users>
};

declare function setup:get-roles($ids as xs:unsignedLong*) as element(sec:roles)? {
  let $roles :=
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       /sec:role',
      (),
      <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
      </options>)
  let $roles :=
    if ($ids) then $roles[sec:role-id = $ids]
    else $roles
  where $roles
  return
    <roles xmlns="http://marklogic.com/xdmp/security">
    {
      for $role in $roles
      return
        element sec:role
        {
          $role/@*,
          $role/*[fn:not(self::sec:role-id) and
                  fn:not(self::sec:role-ids) and
                  fn:not(self::sec:permissions)],
          element sec:role-names
          {
            for $id in $role/sec:role-ids/*
            return
              element sec:role-name {setup:get-role-name($id)}
          },

          element sec:permissions
          {
            for $perm in $role/sec:permissions/sec:permission
            return
              element sec:permission
              {
                $perm/sec:capability,
                element sec:role-name {setup:get-role-name($perm/sec:role-id)}
              }
          },

          element sec:privileges {
            for $priv in setup:get-role-privileges($role)
            return
              element sec:privilege {
                $priv/@*,
                $priv/node()[fn:not(self::sec:privilege-id) and
                             fn:not(self::role-ids)]
              }
          }
        }
    }</roles>
};

declare function setup:get-amps($ids as xs:unsignedLong*) as element(sec:amps)? {
  let $amps :=
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       /sec:amp',
      (),
      <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
      </options>)
  let $amps :=
    if ($ids) then $amps[sec:amp-id = $ids]
    else $amps
  where $amps
  return
    <amps xmlns="http://marklogic.com/xdmp/security">
    {
      for $amp in $amps
      return
        element sec:amp
        {
          $amp/@*,
          $amp/*[fn:not(self::sec:amp-id) and
                  fn:not(self::sec:role-ids) and
                  fn:not(self::sec:database)],
          element sec:role-names
          {
            for $id in $amp/sec:role-ids/*
            return
              element sec:role-name {setup:get-role-name($id)}
          },

          element sec:db-name
          {
            if ($amp/sec:database = 0) then "filesystem"
            else
              xdmp:database-name($amp/sec:database)
          }
        }
    }</amps>
};

declare function setup:get-mimetypes($names as xs:string*) as element(mt:mimetypes)?
{
  let $mimes := setup:read-config-file("mimetypes.xml")/mt:mimetypes
  let $mimes := $mimes/mt:mimetype[mt:name = $names]
  where $mimes
  return
    <mimetypes xsi:schemaLocation="http://marklogic.com/xdmp/mimetypes mimetypes.xsd"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xmlns="http://marklogic.com/xdmp/mimetypes">
      {setup:resolve-ids-to-names($mimes)}
    </mimetypes>
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Resolving IDs to names
 ::)

declare function setup:resolve-database-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      attribute {xs:QName("name")} { xdmp:database-name(fn:data($node)) }
    }
  else ()
};

declare function setup:resolve-forest-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      attribute {xs:QName("name")} { xdmp:forest-name(fn:data($node)) }
    }
  else ()
};

declare function setup:resolve-host-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      attribute {xs:QName("name")} { xdmp:host-name(fn:data($node)) }
    }
  else ()
};

declare function setup:resolve-user-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      attribute {xs:QName("name")} { setup:user-name(fn:data($node)) }
    }
  else ()
};

declare function setup:resolve-ids-to-names($nodes as item()*) as item()*
{
  for $node in $nodes
  return
    typeswitch ($node)

    (: App Server specific :)
      case element(gr:modules) return
        setup:resolve-database-id-to-name($node)

      case element(gr:database) return
        setup:resolve-database-id-to-name($node)

      case element(gr:last-login) return
        setup:resolve-database-id-to-name($node)

      case element(gr:default-user) return
        setup:resolve-user-id-to-name($node)

    (: Database specific :)
      case element(db:security-database) return
        setup:resolve-database-id-to-name($node)

      case element(db:schema-database) return
        setup:resolve-database-id-to-name($node)

      case element(db:triggers-database) return
        setup:resolve-database-id-to-name($node)

      case element(db:forest-id) return
        setup:resolve-forest-id-to-name($node)

    (: Forest specific :)
      case element(as:host) return
        setup:resolve-host-id-to-name($node)

    (: Default :)
      case element() return
        if ($node/node()) then
          element {fn:node-name($node)}
          {
            $node/@*,
            setup:resolve-ids-to-names($node/node())
          }
        else ()

      case document-node() return
        document
        {
          setup:resolve-ids-to-names($node/node())
        }

      default return
        $node
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Stripping default properties
 ::)

declare function setup:strip-default-properties-from-http-server(
  $node as element(gr:http-server)) as element(gr:http-server)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:http-server-create(
        admin:get-configuration(),
        $default-group,
        "default",
        "/",
        19999,
        $default-modules,
        $default-database)//gr:http-servers/gr:http-server[gr:http-server-name eq "default"]/*
    for $property in $node/*
    where fn:not($default-properties[fn:deep-equal(., $property)]) and
          fn:not(xs:boolean($node/gr:webDAV) and $property/self::gr:compute-content-length) and
          fn:not($property/self::gr:http-server-id)
    return
      $property
  }
};

declare function setup:strip-default-properties-from-xdbc-server(
  $node as element(gr:xdbc-server)) as element(gr:xdbc-server)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:xdbc-server-create(
        admin:get-configuration(),
        $default-group,
        "default",
        "/",
        19999,
        $default-modules,
        $default-database)//gr:xdbc-servers/gr:xdbc-server[gr:xdbc-server-name eq "default"]/*
    for $property in $node/*
    where fn:not($default-properties[fn:deep-equal(., $property)]) and
          fn:not($property/self::gr:xdbc-server-id)
    return
      $property
  }
};

declare function setup:strip-default-properties-from-database(
  $node as element(db:database)) as element(db:database)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:database-create(
        admin:get-configuration(),
        "default",
        $default-security,
        $default-schemas)/db:databases/db:database[db:database-name eq "default"]/*
    for $property in $node/*
    where fn:not($default-properties[fn:deep-equal(., $property)]) and
          fn:not($property/self::db:database-id)
    return
      $property
  }
};

declare function setup:strip-default-properties-from-forest(
  $node as element(as:assignment)) as element(as:assignment)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:forest-create(
        admin:get-configuration(),
        "default",
        $default-host,
        ())//as:assignments/as:assignment[as:forest-name eq "default"]/*
    for $property in $node/*
    where fn:not($default-properties[fn:deep-equal(., $property)]) and
          fn:not($property/self::as:forest-id)
    return
      $property
  }
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Accessing import-config
 ::)

declare function setup:get-databases-from-config(
  $import-config as element(configuration)) as element(db:database)*
{
  for $db in $import-config/db:databases/db:database
  return
    if (fn:exists($db/@import)) then
      element db:database
      {
        $db/*,
        let $ignore := $db/*/fn:node-name(.)
        return
          $import-config//db:databases/db:database[db:database-name eq $db/@import]/*[fn:not(fn:node-name(.) = $ignore)]
      }
    else
      $db
};

declare function setup:get-database-name-from-database-config(
  $db-config as element(db:database)) as xs:string?
{
  $db-config/db:database-name[fn:string-length(.) > 0]
};

declare function setup:get-forests-per-host-from-database-config(
  $db-config as element(db:database)) as xs:positiveInteger?
{
  let $forests-per-host := fn:data($db-config/db:forests-per-host)
  return
    if (fn:string-length($forests-per-host) > 0) then
      xs:positiveInteger($forests-per-host)
    else
      xs:positiveInteger("1") (: Default forests per host is 1 :)
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Utility functions
 ::)

declare function setup:read-config-file($filename as xs:string) as document-node()
{
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/admin-module-read", "execute"),
  xdmp:read-cluster-config-file($filename)
};

declare function setup:user-name($user-id as xs:unsignedLong?) as xs:string
{
  let $user-id :=
    if ($user-id) then
      $user-id
    else
      fn:data(xdmp:get-request-user())
  return
    xdmp:eval(
      'xquery version "1.0-ml";
       import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

       declare variable $user-id as xs:unsignedLong external;
       sec:get-user-names($user-id)',
      (xs:QName("user-id"), $user-id),
      <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
      </options>)
};

declare function display:template($title, $main-content, $left-content)
{
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Cluster Configurator -- {$title}</title>
      <style>
      body {{
        margin:0;
        padding:0;
        border:0;     /* This removes the border around the viewport in old versions of IE */
        width:100%;
        background:#fff;
        min-width:600px;      /* Minimum width of layout - remove line if not required */
                /* The min-width property does not work in old versions of Internet Explorer */
        font-size:90%;
        font-family:  Verdana, Arial, Helvetica, sans-serif;
      }}
      a {{
        color:#369;
      }}
      a:hover {{
        color:#fff;
        background:#369;
        text-decoration:none;
      }}
      h1, h2, h3 {{
        margin:.8em 0 .2em 0;
        padding:0;
        font-weight: normal;
      }}
      p {{
        margin:.4em 0 .8em 0;
        padding:0;
      }}
      img {{
        margin:10px 0 5px;
      }}

      form {{
        border:0;
        margin:0;
        padding:0;
      }}

      #lefttree ul {{
        list-style-type:disc;
        margin-left:0.5em;
        padding-left:0.5em;

      }}

      #lefttree li {{
        list-style-type:disc;
        font-size:8pt;
        padding-bottom:0.3em;
      }}

      /* Header styles */
      #header {{
        clear:both;
        float:left;
        width:100%;
        background: #1E90FF;
      }}
      #header {{
        border-bottom:1px solid #000;
      }}
      #header p,
      #header h1,
      #header h2 {{
        padding:.4em 15px 0 15px;
        margin:0;
      }}
      #header h2 {{
        font-size:85%;
      }}
      #header ul {{
        font-size:100%;
        clear:left;
        float:left;
        width:100%;
        list-style:none;
        margin:10px 0 0 0;
        padding:0;
      }}
      #header ul li {{
        display:inline;
        list-style:none;
        margin:0;
        padding:0;
      }}
      #header ul li a {{
        display:block;
        float:left;
        margin:0 0 0 1px;
        padding:3px 10px;
        text-align:center;
        background:#eee;
        color:#000;
        text-decoration:none;
        position:relative;
        left:15px;
        line-height:1.3em;
      }}
      #header ul li a:hover {{
        background:#369;
        color:#fff;
      }}
      #header ul li a.active,
      #header ul li a.active:hover {{
        color:#fff;
        background:#000;
        font-weight:bold;
      }}
      #header ul li a span {{
        display:block;
      }}


      #buttonbar ul {{
        clear:left;
        float:left;
        width:100%;
        list-style:none;
        margin:10px 0 0 0;
        padding:0;
      }}
      #buttonbar ul li {{
        display:inline;
        list-style:none;
        margin:0;
        padding:0;
      }}
      #buttonbar ul li a {{
        display:block;
        float:left;
        margin:0 0 0 1px;
        padding:3px 10px;
        text-align:center;
        background:#ADD8E6;
        color:#000;
        text-decoration:none;
        position:relative;
        left:15px;
        line-height:1.3em;
      }}
      #buttonbar ul li a:hover {{
        background:#369;
        color:#fff;
      }}
      #buttonbar ul li a.active,
      #buttonbar ul li a.active:hover {{
        color:#fff;
        background:black;
        font-weight:bold;
      }}
      #buttonbar ul li a span {{
        display:block;
      }}


      /* 'widths' sub menu */
      #layoutdims {{
        clear:both;
        background:#eee;
        border-top:4px solid #000;
        margin:0;
        padding:6px 15px !important;
        text-align:right;
      }}
      /* column container */
      .colmask {{
        position:relative;  /* This fixes the IE7 overflow hidden bug */
        clear:both;
        float:left;
        width:100%;     /* width of whole page */
        overflow:hidden;    /* This chops off any overhanging divs */
      }}
      /* common column settings */
      .colright,
      .colmid,
      .colleft {{
        float:left;
        width:100%;
        position:relative;
      }}
      .col1,
      .col2,
      .col3 {{
        float:left;
        position:relative;
        padding:0 0 1em 0;
        overflow:hidden;
      }}
      /* 2 Column (left menu) settings */
      .leftmenu {{
        background:#fff;    /* right column background colour */
      }}
      .leftmenu .colleft {{
        right:75%;      /* right column width */
        background:#ADD8E6; /* left column background colour */
      }}
      .leftmenu .col1 {{
        width:71%;      /* right column content width */
        left:102%;      /* 100% plus left column left padding */
      }}
      .leftmenu .col2 {{
        width:21%;      /* left column content width (column width minus left and right padding) */
        left:6%;      /* (right column left and right padding) plus (left column left padding) */
      }}


      /* Footer styles */
      #footer {{
        clear:both;
        float:left;
        width:100%;
        border-top:1px solid #000;
      }}
      #footer p {{
        padding:10px;
        margin:0;
      }}


      td, th {{
        vertical-align: top;
        padding: 10px;
      }}

      table#domainsummary
      {{
        font-size:80%;
        border-width:1px 1px 1px 1px;
        border-style:solid solid solid solid;
        border-collapse:collapse;
        border-color:1E90FF;
      }}

      table#domainsummary th,td
      {{
        border-width:1px 1px 1px 1px;
        border-style:solid solid solid solid;
        border-collapse:collapse;
        border-color:1E90FF;
      }}
    </style>
    </head>
    <body>

    <div id="header">
      <!-- <p>Text above heading</p> -->
      <h1>Cluster Configurator</h1>
      <h2>{$title}</h2>
      <p></p>
      <!-- <p id="layoutdims">Right aligned bar</p>-->
    </div>
    <div class="colmask leftmenu">
      <div class="colleft">
        <div class="col1">
          <!-- Column 1 start -->
          {
            $main-content
          }
          <!-- Column 1 end -->
        </div>
        <div class="col2">
          <!-- Column 2 start -->
          {
            $left-content
          }
          <!-- Column 2 end -->
        </div>
      </div>
    </div>
    <div id="footer">
      <p>&copy; Copyright 2010 Mark Logic Corporation.  All rights reserved.</p>
    </div>
    </body>
  </html>
};

declare function display:tab-bar($labels, $links, $index)
{
  (
    <span id="buttonbar" xmlns="http://www.w3.org/1999/xhtml">
      <ul>
      {
        for $label at $i in $labels
        return
          <li>
          {
              element a
              {
                if ($i = $index) then
                  attribute class {"active"}
                else
                  (),
                attribute href {$links[$i]},
                $label
              }
          }
          </li>
      }
      </ul>
    </span>,
    <p xmlns="http://www.w3.org/1999/xhtml"><br/>&nbsp;<br/></p>
  )
};

declare function display:dropdown($name, $options, $selected, $disabled)
{
  element select
  {
    attribute id {$name},
    attribute name {$name},

    if ($disabled) then
      attribute disabled {"disabled"}
    else
      (),

    for $option in $options
    return
    element option
    {
      attribute value {$option},
      if ($selected eq $option) then
        attribute selected {"selected"}
      else
        (),
      $option
    }
  }
};

declare function display:radio($name, $value, $selected)
{
  element input
  {
    attribute type {"radio"},
    attribute name {$name},
    attribute value {$value},

    if ($value eq $selected) then
      attribute checked {"checked"}
    else
      ()
  }
};

declare function display:vertical-spacer($n)
{
  <p>
  {
    for $i in (1 to $n)
    return ("&nbsp;", <br />)
  }
  </p>
};

declare function display:left-links()
{
  <div>
  &nbsp;<br/>
  &nbsp;<br/>
  &nbsp;<br/>
  <p><a href="export.xqy">Export</a></p>
  <p><a href="import.xqy">Import</a></p>
  </div>
};

declare function display:export-ui()
{
  let $databases := xdmp:get-request-field("databases", "")
  let $forests := xdmp:get-request-field("forests", "")
  let $servers := xdmp:get-request-field("servers", "")
  let $user-ids as xs:unsignedLong* :=
    for $x in xdmp:get-request-field("users", ())
    return
      xs:unsignedLong($x)
  let $role-ids as xs:unsignedLong* :=
    for $x in xdmp:get-request-field("roles", ())
    return
      xs:unsignedLong($x)
  let $submit := xdmp:get-request-field("submit", "")
  return
    if ($submit eq "Export") then
      let $config := setup:get-configuration($databases, $forests, $servers, $user-ids, $role-ids, ())
      let $type := xdmp:add-response-header("Content-Type", "text/xml")
      let $disp := xdmp:add-response-header("Content-Disposition", "attachment; filename=config.xml")
      return $config
    else
      display:template(
        "Export Configuration",
        <div xmlns="http://www.w3.org/1999/xhtml">
          <form method="POST" action="" name="export">
            <input type="hidden" name="queryInput" value="{xdmp:get-request-field('queryInput')}"/>
            <table class="foo" width="100%" style="border-width:0px">
            <tr>
              <td valign="top" style="border-width:0px">
                <h3>Databases</h3>
                {
                  for $database-id in xdmp:databases()
                  let $database := xdmp:database-name($database-id)
                  order by $database
                  return (<input type="checkbox" name="databases" value="{$database}" />, $database, <br/>)
                }
              </td>
              <td valign="top" style="border-width:0px">
                <h3>Forests</h3>
                {
                  for $forest-id in xdmp:forests()
                  let $forest := xdmp:forest-name($forest-id)
                  order by $forest
                  return (<input type="checkbox" name="forests" value="{$forest}" />, $forest, <br/>)
                }
              </td>
              <td valign="top" style="border-width:0px">
                <h3>App Servers</h3>
                {
                  for $server-id in xdmp:servers()
                  let $server := xdmp:server-name($server-id)
                  order by $server
                  return (<input type="checkbox" name="servers" value="{$server}" />, $server, <br/>)
                }
              </td>
              <td valign="top" style="border-width:0px">
                <h3>Users</h3>
                {
                  for $user in xdmp:eval("/sec:user", (), <options xmlns="xdmp:eval">
                                                            <database>{xdmp:database("Security")}</database>
                                                          </options>)
                  order by $user/sec:user-name
                  return (<input type="checkbox" name="users" value="{$user/sec:user-id}" />, $user/sec:user-name, <br/>)
                }
              </td>
              <td valign="top" style="border-width:0px">
                <h3>Roles</h3>
                {
                  for $user in xdmp:eval("/sec:role", (), <options xmlns="xdmp:eval">
                                                            <database>{xdmp:database("Security")}</database>
                                                          </options>)
                  order by $user/sec:role-name
                  return (<input type="checkbox" name="roles" value="{$user/sec:role-id}" />, $user/sec:role-name, <br/>)
                }
              </td>
            </tr>
            </table>

            <input type="submit" name="submit" value="Export"/>
          </form>
        </div>,
        display:left-links()
        )
};

declare function setup:validation-fail($message)
{
  xdmp:log($message),
  fn:error(xs:QName("VALIDATION-FAIL"), $message)
};

declare function setup:validate-install($import-config as element(configuration))
{
  setup:validate-privileges($import-config),
  setup:validate-roles($import-config),
  setup:validate-users($import-config),
  setup:validate-mimetypes($import-config),
  setup:validate-forests($import-config),
  setup:validate-databases($import-config),
  setup:validate-attached-forests($import-config),
  setup:validate-amps($import-config),
  setup:validate-database-settings($import-config),
  setup:validate-databases-indexes($import-config),
  setup:validate-appservers($import-config)
};