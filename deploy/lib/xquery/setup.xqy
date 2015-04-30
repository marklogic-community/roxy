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

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
import module namespace pki = "http://marklogic.com/xdmp/pki" at "/MarkLogic/pki.xqy";

declare namespace setup = "http://marklogic.com/roxy/setup";
declare namespace xdmp="http://marklogic.com/xdmp";
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace db="http://marklogic.com/xdmp/database";
declare namespace gr="http://marklogic.com/xdmp/group";
declare namespace err="http://marklogic.com/xdmp/error";
declare namespace ho="http://marklogic.com/xdmp/hosts";
declare namespace as="http://marklogic.com/xdmp/assignments";
declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace mt="http://marklogic.com/xdmp/mimetypes";

declare option xdmp:mapping "false";

declare variable $default-host := xdmp:host();
declare variable $default-database := xdmp:database();
declare variable $default-modules := xdmp:database("Modules");
declare variable $default-schemas := xdmp:database("Schemas");
declare variable $default-security := xdmp:database("Security");
declare variable $default-user := xdmp:user("nobody");

declare variable $roll-back := map:map();

declare variable $restart-needed as xs:boolean := fn:false();

declare variable $system-users := ("nobody", "infostudio-admin", "healthcheck");

declare variable $system-roles as xs:string+ :=
  setup:read-config-file("security.xml")/sec:security/sec:roles/sec:role/@name;

declare variable $group-settings :=
  <settings>
    <setting>list-cache-size</setting>
    <setting>list-cache-partitions</setting>
    <setting>compressed-tree-cache-size</setting>
    <setting>compressed-tree-cache-partitions</setting>
    <setting>compressed-tree-read-size</setting>
    <setting>expanded-tree-cache-size</setting>
    <setting>expanded-tree-cache-partitions</setting>
    <setting>triple-cache-size</setting>
    <setting>triple-cache-partitions</setting>
    <setting>triple-cache-timeout</setting>
    <setting>triple-value-cache-size</setting>
    <setting>triple-value-cache-partitions</setting>
    <setting>triple-value-cache-timeout</setting>
    
    <setting>smtp-relay</setting>
    <setting>smtp-timeout</setting>
    <setting>http-user-agent</setting>
    <setting>http-timeout</setting>
    <setting>xdqp-timeout</setting>
    <setting>host-timeout</setting>
    <setting>host-initial-timeout</setting>
    <setting>retry-timeout</setting>
    <setting>module-cache-timeout</setting>
    
    <setting>system-log-level</setting>
    <setting>file-log-level</setting>
    <setting>rotate-log-files</setting>
    <setting>keep-log-files</setting>
    
    <setting>failover-enable</setting>
    <setting>xdqp-ssl-enabled</setting>
    <setting>xdqp-ssl-allow-sslv3</setting>
    <setting>xdqp-ssl-allow-tls</setting>
    <setting>xdqp-ssl-ciphers</setting>
    
    <setting>background-io-limit</setting>
    <setting>metering-enabled</setting>
    <setting>performance-metering-enabled</setting>
    <!--TODO: setting>meters-database</setting-->
    <setting>performance-metering-period</setting>
    <setting>performance-metering-retain-raw</setting>
    <setting>performance-metering-retain-hourly</setting>
    <setting>performance-metering-retain-daily</setting>
    
    <setting>s3-domain</setting>
    <setting>s3-protocol</setting>
    <setting>s3-server-side-encryption</setting>
    <!--DANGEROUS: setting>security-database</setting-->
    
    <!-- Diagnostics -->
    <setting>trace-events-activated</setting>
    
    <!-- Auditing -->
    <setting>audit-enabled</setting>
    <setting>rotate-audit-files</setting>
    <setting>keep-audit-files</setting>
    <setting>audit-outcome-restriction</setting>
    <!--TODO: setting>audit-role-restriction</setting>
    <setting>audit-uri-restriction</setting>
    <setting>audit-user-restriction</setting-->
  </settings>;

declare variable $host-settings :=
  <settings>
    <setting>foreign-port</setting>
    <setting value="setup:get-host-group($host-config)">group</setting>
    <setting>port</setting>
    <setting>zone</setting>
  </settings>;

declare variable $database-settings :=
  <settings>
    <setting>enabled</setting>
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
    <setting>field-value-searches</setting>
    <setting>field-value-positions</setting>
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
    <setting>in-memory-limit</setting>
    <setting>in-memory-list-size</setting>
    <setting>in-memory-tree-size</setting>
    <setting>in-memory-range-index-size</setting>
    <setting>in-memory-reverse-index-size</setting>
    <setting>large-size-threshold</setting>
    <setting>locking</setting>
    <setting>journaling</setting>
    <setting>journal-size</setting>
    <setting>preallocate-journals</setting>
    <setting>preload-mapped-data</setting>
    <setting>preload-replica-mapped-data</setting>
    <setting>range-index-optimize</setting>
    <setting>positions-list-max-size</setting>
    <setting>format-compatibility</setting>
    <setting>index-detection</setting>
    <setting>expunge-locks</setting>
    <setting>tf-normalization</setting>
    <setting>merge-priority</setting>
    <setting>merge-max-size</setting>
    <setting>merge-min-size</setting>
    <setting>merge-min-ratio</setting>
    <setting>merge-timestamp</setting>
    <setting min-version="7.0-0">triple-index</setting>
    <setting min-version="7.0-0">rebalancer-enable</setting>
    <setting min-version="7.0-0">rebalancer-throttle</setting>
    <setting min-version="7.0-0">in-memory-triple-index-size</setting>
    <setting min-version="7.0-0">journal-count</setting>
  </settings>;

declare variable $common-server-settings :=
  <settings>
    <setting>enabled</setting>
    <setting>root</setting>
    <setting>port</setting>
    <setting value="setup:get-appserver-content-database($server-config)">database</setting>
    <setting value="setup:get-last-login($server-config)">last-login</setting>
    <setting>display-last-login</setting>
    <setting>address</setting>
    <setting>backlog</setting>
    <setting>threads</setting>
    <setting>request-timeout</setting>
    <setting>keep-alive-timeout</setting>
    <setting>session-timeout</setting>
    <setting>max-time-limit</setting>
    <setting>default-time-limit</setting>
    <setting>pre-commit-trigger-depth</setting>
    <setting>pre-commit-trigger-limit</setting>
    <setting>collation</setting>
    <setting min-version="7.0-0" if="fn:not(setup:get-appserver-external-security($server-config))" value="setup:get-appserver-internal-security($server-config)">internal-security</setting>
    <setting if="fn:not(setup:get-appserver-external-security($server-config))">authentication</setting>
    <setting value="setup:get-appserver-privilege($server-config)">privilege</setting>
    <setting>concurrent-request-limit</setting>
    <setting>log-errors</setting>
    <setting>debug-allow</setting>
    <setting>profile-allow</setting>
    <setting>default-xquery-version</setting>
    <setting min-version="7.0-0">distribute-timestamps</setting>
    <setting min-version="5.0-0">multi-version-concurrency-control</setting>
    <setting>output-sgml-character-entities</setting>
    <setting>output-encoding</setting>
    <setting min-version="5.0-0">output-method</setting>
    <setting min-version="5.0-0">output-byte-order-mark</setting>
    <setting min-version="5.0-0">output-cdata-section-namespace-uri</setting>
    <setting min-version="5.0-0">output-cdata-section-localname</setting>
    <setting min-version="5.0-0">output-doctype-public</setting>
    <setting min-version="5.0-0">output-doctype-system</setting>
    <setting min-version="5.0-0">output-escape-uri-attributes</setting>
    <setting min-version="5.0-0">output-include-content-type</setting>
    <setting min-version="5.0-0">output-indent</setting>
    <setting min-version="5.0-0">output-indent-untyped</setting>
    <setting min-version="5.0-0">output-media-type</setting>
    <setting min-version="5.0-0">output-normalization-form</setting>
    <setting min-version="5.0-0">output-omit-xml-declaration</setting>
    <setting min-version="5.0-0">output-standalone</setting>
    <setting min-version="5.0-0">output-undeclare-prefixes</setting>
    <setting min-version="5.0-0">output-version</setting>
    <setting min-version="5.0-0">output-include-default-attributes</setting>
    <setting value="setup:get-ssl-certificate-template($server-config)">ssl-certificate-template</setting>
    <setting>ssl-allow-sslv3</setting>
    <setting>ssl-allow-tls</setting>
    <setting>ssl-hostname</setting>
    <setting>ssl-ciphers</setting>
    <setting>ssl-require-client-certificate</setting>
  </settings>
;

declare variable $http-server-settings :=
  <settings>
    { $common-server-settings/* }
    <setting value="setup:get-appserver-modules-database($server-config)">modules-database</setting>
    <setting accept-blank="true">error-handler</setting>
    <setting accept-blank="true">url-rewriter</setting>
    <setting min-version="6.0-1">rewrite-resolves-globally</setting>
    <setting>static-expires</setting>
    <setting if="fn:not(setup:get-appserver-external-security($server-config))" value="setup:get-appserver-default-user($server-config)">default-user</setting>
  </settings>
;

declare variable $webdav-server-settings :=
  <settings>
    { $common-server-settings/* }
    <setting>compute-content-length</setting>
    <setting>static-expires</setting>
    <setting value="setup:get-appserver-default-user($server-config)">default-user</setting>
  </settings>
;

declare variable $xdbc-server-settings :=
  <settings>
    { $common-server-settings/* }
    <setting value="setup:get-appserver-modules-database($server-config)">modules-database</setting>
  </settings>
;

declare variable $odbc-server-settings :=
  $xdbc-server-settings
;

declare variable $task-server-settings :=
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
  </settings>;

declare variable $field-settings :=
  <settings>
    <setting>fast-case-sensitive-searches</setting>
    <setting>fast-diacritic-sensitive-searches</setting>
    <setting>fast-phrase-searches</setting>
    <setting>one-character-searches</setting>
    <setting>stemmed-searches</setting>
    <setting>three-character-searches</setting>
    <setting>three-character-word-positions</setting>
    <setting>trailing-wildcard-searches</setting>
    <setting>trailing-wildcard-word-positions</setting>
    <setting>two-character-searches</setting>
    <setting min-version="6.0-1">value-positions</setting>
    <setting min-version="6.0-1">value-searches</setting>
    <setting min-version="6.0-1">field-value-positions</setting>
    <setting min-version="6.0-1">field-value-searches</setting>
    <setting>word-searches</setting>
  </settings>;
  
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
  element configuration
  {
    map:get($roll-back, "task-server"),

    element gr:http-servers
    {
      map:get($roll-back, "http-servers")
    },
    element gr:xdbc-servers
    {
      map:get($roll-back, "xdbc-servers")
    },
    element gr:odbc-servers
    {
      map:get($roll-back, "odbc-servers")
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
    },
    map:get($roll-back, "external-security")
  }
};

(: for backwards-compatibility :)
declare function setup:rewrite-config($import-configs as element(configuration)+) as element(configuration)
{
  let $config :=
    element { fn:node-name($import-configs[1]) } {
      $import-configs/@*,
    
      <groups xmlns="http://marklogic.com/xdmp/group" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd">{
        let $default-group := ($import-configs/@default-group, "Default")[1]
        for $group in fn:distinct-values(
          ($import-configs/(gr:http-servers/gr:http-server | gr:xdbc-servers/gr:xdbc-server |
            gr:odbc-servers/gr:odbc-server | gr:task-server | db:databases/db:database)/@group, $default-group))
        let $http-servers := $import-configs/gr:http-servers/gr:http-server[@group = $group or ($group = $default-group and fn:empty(@group))]
        let $xdbc-servers := $import-configs/gr:xdbc-servers/gr:xdbc-server[@group = $group or ($group = $default-group and fn:empty(@group))]
        let $odbc-servers := $import-configs/gr:odbc-servers/gr:odbc-server[@group = $group or ($group = $default-group and fn:empty(@group))]
        let $task-server := $import-configs/gr:task-server[@group = $group or ($group = $default-group and fn:empty(@group))]
        let $servers := ($http-servers, $xdbc-servers, $odbc-servers, $task-server)
        let $databases := $import-configs/db:databases/db:database[@group = $group or ($group = $default-group and fn:empty(@group))]
        let $group-config := $import-configs/gr:groups/gr:group[gr:group-name = $group]
        where fn:exists($servers | $databases | $group-config)
        return
          <group>
            <group-name>{$group}</group-name>
            {
              if ($http-servers) then
                <http-servers>{$http-servers}</http-servers>
              else (),
              if ($xdbc-servers) then
                <xdbc-servers>{$xdbc-servers}</xdbc-servers>
              else (),
              if ($odbc-servers) then
                <odbc-servers>{$odbc-servers}</odbc-servers>
              else (),
              if ($task-server) then
                $task-server
              else (),
              $group-config/(node() except gr:group-name)
            }
          </group>
      }</groups>,
    
      $import-configs/(node() except (gr:groups | gr:http-servers | gr:xdbc-servers | gr:odbc-servers | gr:task-server))
    }
  
  (: Check config on group consistency! :)
  let $_ :=
    for $group in $config/gr:groups/gr:group/gr:group-name
    let $hosts := ($config/ho:hosts/ho:host[ho:group/@name = $group], try { xdmp:group-hosts(xdmp:group($group)) } catch ($ignore) {})
    where fn:empty($hosts)
    return
      fn:error(
        xs:QName("NO_HOSTS_IN_GROUP"),
        fn:concat("No hosts assigned to group ", $group, ", needed for app servers and forests!"))

  (: all good :)
  return $config
};

declare function setup:do-setup($import-config as element(configuration)+) as item()*
{
  try
  {
    let $import-config := setup:rewrite-config($import-config)
    return (
      setup:create-ssl-certificate-templates($import-config),
      setup:create-privileges($import-config),
      setup:create-roles($import-config),
      setup:create-users($import-config),
      setup:create-external-security($import-config),
      setup:create-mimetypes($import-config),
      setup:create-groups($import-config),
      setup:configure-groups($import-config),
      setup:configure-hosts($import-config),
      setup:create-forests($import-config),
      setup:create-databases($import-config),
      setup:attach-forests($import-config),
      setup:create-amps($import-config),
      setup:apply-database-settings($import-config),
      setup:configure-databases($import-config),
      setup:create-appservers($import-config),
      setup:apply-appservers-settings($import-config),
      setup:create-scheduled-tasks($import-config),
      if ($restart-needed) then
        "note: restart required"
      else ()
    )
  }
  catch($ex)
  {
    if ($ex/error:code = "ADMIN-INVALIDAUTHENTICATION") then
      fn:concat('&#10;
        Either your authentication configuration is invalid or you
        are trying to change from external authentication back to internal authentication. There is a bug
        in MarkLogic''s Admin API which prevents going from external back to internal.&#10;
        See http://docs.marklogic.com/guide/security/external-auth#id_63262 for more information on
        configuring external authentication.&#10;&#10;' )
    else (),
    xdmp:log($ex),
    setup:do-wipe(setup:get-rollback-config()),
    fn:concat($ex/err:format-string/text(), '&#10;See MarkLogic Server error log for more details.')
  }
};

declare function setup:do-wipe($import-config as element(configuration)+) as item()*
{
  try
  {
    let $import-config := setup:rewrite-config($import-config)
    return (
  
      (: remove scheduled tasks :)
      let $admin-config := admin:get-configuration()
      let $remove-tasks :=
        for $task-server in $import-config/gr:groups/gr:group/gr:task-server
        let $group-id := try { setup:get-group($task-server) } catch ($ignore) {}
        where $group-id
        return
          for $task in $task-server/gr:scheduled-tasks/gr:scheduled-task
          let $existing := setup:get-scheduled-task($task, $group-id)
          where $existing
          return
            xdmp:set(
              $admin-config,
              admin:group-delete-scheduled-task($admin-config, $group-id, $existing))
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),

      (: remove appservers :)
      let $admin-config := admin:get-configuration()
      let $remove-appservers :=
        for $app-server in $import-config/gr:groups/gr:group/(gr:http-servers/gr:http-server,
          gr:xdbc-servers/gr:xdbc-server, gr:odbc-servers/gr:odbc-server)
        let $group-id := try { setup:get-group($app-server) } catch ($ignore) {}
        for $as-name in ($app-server/(gr:http-server-name|gr:xdbc-server-name|gr:odbc-server-name))
        where $group-id
        return
          if (admin:appserver-exists($admin-config, $group-id, $as-name)) then
            xdmp:set(
              $admin-config,
              admin:appserver-delete(
                $admin-config,
                admin:appserver-get-id($admin-config, $group-id, $as-name)))
          else ()
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),

      (: remove certificates :)
      let $certificates := $import-config/pki:certificates
      where $certificates
      return
        xdmp:eval('
          import module namespace pki = "http://marklogic.com/xdmp/pki" at "/MarkLogic/pki.xqy";

          declare variable $certificates external;

          for $cert-name in $certificates/pki:certificate/pki:name/fn:string()
          let $cert := pki:get-template-by-name($cert-name)
          where $cert
          return pki:delete-template(pki:template-get-id($cert))
          ',
          (xs:QName("certificates"), $certificates),
          <options xmlns="xdmp:eval">
            <database>{xdmp:security-database()}</database>
          </options>
        ),

      (: remove amps :)
      let $admin-config := admin:get-configuration()
      for $amp in $import-config/sec:amps/sec:amp
      where admin:database-exists($admin-config, $amp/sec:db-name)
      return
        try
        {
          xdmp:eval(
            'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $amp external;
             if (sec:amp-exists($amp/sec:namespace, $amp/sec:local-name, $amp/(sec:doc-uri, sec:document-uri)[1], xdmp:database($amp/sec:db-name))) then
               sec:remove-amp(
                 $amp/sec:namespace,
                 $amp/sec:local-name,
                 $amp/(sec:doc-uri, sec:document-uri)[1],
                 xdmp:database($amp/sec:db-name))
             else ()',
            (xs:QName("amp"), $amp),
            <options xmlns="xdmp:eval">
              <database>{$default-security}</database>
            </options>)
        }
        catch($ex)
        {
          if ($ex/error:code = "SEC-AMPDNE") then ()
          else
            xdmp:rethrow()
        },

      (: remove databases :)
      let $databases :=
        (
          (: process databases depending on others first :)
          $import-config/db:databases/db:database[db:security-database or db:schema-database or db:triggers-database],
          (: process databases that are likely depended on last :)
          $import-config/db:databases/db:database[fn:not(db:security-database or db:schema-database or db:triggers-database)]
        )
      for $db-config in $databases
      return
        setup:delete-databases($db-config),

      (: remove forests :)
      let $admin-config := admin:get-configuration()
      let $remove-forests :=
        let $all-replica-names as xs:string* := $import-config/as:assignments/as:assignment/as:replica-names/as:replica-name
        for $assignment in $import-config/as:assignments/as:assignment[fn:not(as:forest-name = $all-replica-names)]
        let $forest-name := $assignment/as:forest-name
        let $db-config := $import-config/db:databases/db:database[db:forests/db:forest-id/@name = $forest-name]
        let $group-id := try { setup:get-group($db-config) } catch ($ignore) {}
        where $group-id
        return
        let $forests-per-host as xs:integer? := $db-config/db:forests-per-host
        let $forest-names := (
          $forest-name,
          if (fn:exists($forests-per-host)) then
            let $database-name := setup:get-database-name-from-database-config($db-config)
            for $host at $hostnr in admin:group-get-host-ids($admin-config, $group-id)
            for $forestnr in (1 to $forests-per-host)
            return
              fn:string-join(($database-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
          else ()
        )
        let $replica-names := $assignment/as:replica-names/as:replica-name[fn:string-length(fn:string(.)) > 0]
        let $replica-names := (
          $replica-names,
          if (fn:exists($forests-per-host)) then
            (: generates too many names actually, filtered later :)
            let $hosts := admin:group-get-host-ids(admin:get-configuration(), $group-id)
            for $host at $hostnr in $hosts
            for $forestnr in (1 to $forests-per-host)
            for $replica in $import-config/as:assignments/as:assignment[as:forest-name = $replica-names]
            let $replica-name as xs:string := ($replica/as:forest-name[fn:string-length(fn:string(.)) > 0], fn:concat($forest-name, '-replica'))[1]
            return
              fn:string-join(($replica-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
          else ()
        )
        for $forest-name in $forest-names
        return
          if (admin:forest-exists($admin-config, $forest-name)) then
            let $forest-id := admin:forest-get-id($admin-config, $forest-name)
            return
            (
              for $replica-name in $replica-names
              where admin:forest-exists($admin-config, $replica-name)
              return
                let $replica-id := admin:forest-get-id($admin-config, $replica-name)
                (: double check it is really a replica of current forest :)
                where admin:forest-get-replicas($admin-config, $forest-id) = $replica-id
                return
                (
                  xdmp:set($admin-config, admin:forest-remove-replica($admin-config, $forest-id, $replica-id)),
                  xdmp:set($admin-config, admin:forest-delete($admin-config, $replica-id, fn:true()))
                ),

              try {
                xdmp:set(
                  $admin-config,
                  admin:forest-delete(
                    $admin-config,
                    $forest-id, fn:true()))
              }
              catch($ex) {
                xdmp:set(
                  $admin-config,
                  admin:forest-delete(
                    $admin-config,
                    $forest-id, fn:false()))
              }
          )
          else ()
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),

      (: detach hosts :)
      let $admin-config := admin:get-configuration()
      let $detach-hosts :=
        for $group in $import-config/gr:groups/gr:group/gr:group-name[fn:not(. = "Default")]
        return
          if (admin:group-exists($admin-config, $group)) then
            let $group-id := xdmp:group($group)
            let $default-group-id := xdmp:group("Default")
            for $host-id in admin:group-get-host-ids($admin-config, $group-id)
            return
              xdmp:set(
                $admin-config,
                admin:host-set-group(
                  $admin-config,
                  $host-id,
                  $default-group-id))
          else ()
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          (:xdmp:set($restart-needed, fn:true()):)
          fn:error(xs:QName("RESTART_NOW"),"")
        else (),

      (: remove groups :)
      let $admin-config := admin:get-configuration()
      let $remove-groups :=
        for $group in $import-config/gr:groups/gr:group/gr:group-name[fn:not(. = "Default")]
        return
          if (admin:group-exists($admin-config, $group)) then
            let $group-id := xdmp:group($group)
            return
              xdmp:set(
                $admin-config,
                admin:group-delete(
                  $admin-config,
                  $group-id))
          else ()
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),

      (: remove mimetypes :)
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

      (: remove users :)
      for $user in $import-config/sec:users/sec:user/sec:user-name[fn:not(. = $system-users)]
      return
        try
        {
          xdmp:eval(
            'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $user as xs:string external;
             sec:remove-user($user)',
            (xs:QName("user"), $user),
            <options xmlns="xdmp:eval">
              <database>{$default-security}</database>
            </options>)
        }
        catch($ex)
        {
          if ($ex/error:code = "SEC-USERDNE") then ()
          else
            xdmp:rethrow()
        },

      (: remove roles :)
      for $role in $import-config/sec:roles/sec:role/sec:role-name[fn:not(. = $system-roles)]
      return
        try
        {
          xdmp:eval(
            'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $role as xs:string external;
             sec:remove-role($role)',
            (xs:QName("role"), $role),
            <options xmlns="xdmp:eval">
              <database>{$default-security}</database>
            </options>)
        }
        catch($ex)
        {
          if ($ex/error:code = "SEC-ROLEDNE") then ()
          else
            xdmp:rethrow()
        },

      (: remove privileges :)
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
              <database>{$default-security}</database>
            </options>)
        }
        catch($ex)
        {
          if ($ex/error:code = "SEC-PRIVDNE") then ()
          else
            xdmp:rethrow()
        },

      (: remove external security :)
      for $es in $import-config/sec:external-securities/sec:external-security
      return
        try
        {
          xdmp:eval(
            'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $name as xs:string external;

             sec:remove-external-security($name)',
            (xs:QName("name"), $es/sec:external-security-name),
            <options xmlns="xdmp:eval">
              <database>{$default-security}</database>
            </options>)
        }
        catch($ex)
        {
          if ($ex/error:code = "SEC-EXTERNALSECURITYDNE") then ()
          else
            xdmp:rethrow()
        },

      (: remove orphaned amps :)
      for $amp in
        xdmp:eval('
          import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
          for $amp in fn:collection(sec:amps-collection())/*
          let $db-exists :=
            if ($amp/sec:database ne 0) then
              try{
                let $_ := xdmp:database-name($amp/sec:database)
                return fn:true()
              } catch($ignore){
                fn:false()
              }
            else fn:true() 
          where fn:not($db-exists)
          return (
            $amp,
            sec:remove-amp(
              $amp/sec:namespace,
              $amp/sec:local-name,
              $amp/sec:document-uri,
              $amp/sec:database
            )
          )',
          (),
          <options xmlns="xdmp:eval">
            <database>{$default-security}</database>
          </options>
        )
      return
        xdmp:log(fn:concat("Removed orphaned amp ", fn:string-join($amp/(sec:namespace,sec:local-name,sec:document-uri,sec:database)/fn:string(.), ", "), "..")),

      if ($restart-needed) then
        "note: restart required"
      else ()
    )
  
  }
  catch($ex)
  {
    xdmp:log($ex),
    fn:concat($ex/err:format-string/text(), '&#10;See MarkLogic Server error log for more details.')
  }
};

declare function setup:delete-databases($db-config as element(db:database))
{
  let $db-name := $db-config/db:database-name
  let $admin-config := admin:get-configuration()
  return
    if (admin:database-exists($admin-config, $db-name)) then
      let $db-id := admin:database-get-id($admin-config, $db-name)
      let $forest-ids := admin:database-get-attached-forests($admin-config, $db-id)
      let $detach :=
        for $id in $forest-ids
        return
          xdmp:set($admin-config, admin:database-detach-forest($admin-config, $db-id, $id))
      let $delete := xdmp:set($admin-config, admin:database-delete($admin-config, $db-id))
      return
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else ()
    else ()
};

declare function setup:do-restart($group-name as xs:string?) as item()*
{
  try
  {
    let $group-id :=
      if ($group-name = "") then
        xdmp:group()
      else
        try { xdmp:group($group-name) } catch($ignore) {}
    let $group-name :=
      if ($group-id) then
        xdmp:group-name($group-id)
      else
        $group-name
    let $host-ids :=
      if ($group-id) then
        xdmp:group-hosts($group-id)
      else if ($group-name = "cluster") then
        xdmp:hosts()
      else
        fn:error((), "XDMP-NOSUCHGROUP")
    return
    (
      xdmp:restart(
        $host-ids,
        "Restarting hosts to make configuration changes take effect"),
        
      if ($group-id) then
        fn:concat("Group ", $group-name, " restarted")
      else
        fn:concat("Cluster restarted")
    )
  }
  catch ($ex)
  {
    if ($ex/error:code = "XDMP-NOSUCHGROUP") then
      fn:concat("Cannot restart group ", $group-name, ", no such group")
    else
      xdmp:rethrow()
  }
};

declare function setup:find-forest-ids(
  $db-config as element(db:database)) as xs:unsignedLong*
{
  let $group-id := setup:get-group($db-config)
  let $admin-config := admin:get-configuration()
  for $host at $hostnr in admin:group-get-host-ids($admin-config, $group-id)
  for $forestnr in (1 to $db-config/db:forests-per-host)
  let $name :=
    fn:string-join((
      $db-config/db:database-name,
      fn:format-number(xs:integer($hostnr), "000"),
      xs:string($forestnr)),
      "-")
  return
    if (admin:forest-exists($admin-config, $name)) then
      admin:forest-get-id($admin-config, $name)
    else ()
};

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

declare function setup:create-forests($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host as xs:integer? := $db-config/db:forests-per-host
  where fn:not($database-name = 'filesystem')
  return
    if (fn:exists($forests-per-host)) then
      setup:create-forests-from-count($import-config, $db-config, $database-name, $forests-per-host)
    else
      setup:create-forests-from-config($import-config, $db-config, $database-name)
};

declare function setup:validate-forests($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host as xs:integer? := $db-config/db:forests-per-host
  where fn:not($database-name = 'filesystem')
  return
    if (fn:exists($forests-per-host)) then
      setup:validate-forests-from-count($import-config, $db-config, $database-name, $forests-per-host)
    else
      setup:validate-forests-from-config($import-config, $db-config, $database-name)
};

declare function setup:create-forests-from-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string) as item()*
{
  let $group-id := setup:get-group($db-config)
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  for $forest-name as xs:string in $forest-config/as:forest-name[fn:string-length(fn:string(.)) > 0]
  let $data-directory as xs:string? := $forest-config/as:data-directory[fn:string-length(fn:string(.)) > 0]
  let $hosts := admin:group-get-host-ids(admin:get-configuration(), $group-id)
  let $host-name as xs:string? := $forest-config/as:host-name[fn:string-length(fn:string(.)) > 0]
  let $host-id := if ($host-name) then xdmp:host($host-name) else $default-host
  let $hostnr := fn:index-of($hosts, $host-id)
  let $replica-names as xs:string* := $forest-config/as:replica-names/as:replica-name[fn:string-length(fn:string(.)) > 0]
  let $replicas :=
    if (fn:count($hosts) gt 1) then
      $import-config/as:assignments/as:assignment[as:forest-name = $replica-names]
    else ()
  return
    setup:create-forest(
      $forest-name,
      $data-directory,
      $host-id,
      setup:reassign-replicas($replicas, $hosts, $hostnr, $forest-name, 1, fn:false()))

};

declare function setup:validate-forests-from-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string)
{
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  let $forest-name as xs:string? := $forest-config/as:forest-name[fn:string-length(fn:string(.)) > 0]
  let $data-directory as xs:string? := $forest-config/as:data-directory[fn:string-length(fn:string(.)) > 0]
  let $host-name as xs:string? := $forest-config/as:host-name[fn:string-length(fn:string(.)) > 0]
  let $replica-names as xs:string* := $forest-config/as:replica-names/as:replica-name[fn:string-length(fn:string(.)) > 0]
  return
    setup:validate-forest(
      $forest-name,
      $data-directory,
      if ($host-name) then xdmp:host($host-name) else (),
      $replica-names)
};

declare function setup:create-forests-from-count(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string,
  $forests-per-host as xs:int) as item()*
{
  let $group-id := setup:get-group($db-config)
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  for $forest-name as xs:string in $forest-config/as:forest-name[fn:string-length(fn:string(.)) > 0]
  let $data-directory as xs:string? := ($forest-config/as:data-directory[fn:string-length(fn:string(.)) > 0], $db-config/db:forests/db:data-directory)[1]
  let $hosts := admin:group-get-host-ids(admin:get-configuration(), $group-id)
  for $host at $hostnr in $hosts
  for $forestnr in (1 to $forests-per-host)
  let $new-forest-name := fn:string-join(($forest-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
  let $replica-names as xs:string* := $forest-config/as:replica-names/as:replica-name[fn:string-length(fn:string(.)) > 0]
  let $replicas :=
    if (fn:count($hosts) gt 1) then
      $import-config/as:assignments/as:assignment[as:forest-name = $replica-names]
    else ()
  return
    setup:create-forest(
      $new-forest-name,
      $data-directory,
      $host,
      setup:reassign-replicas($replicas, $hosts, $hostnr, $forest-name, $forestnr, fn:true()))
};

declare function setup:reassign-replicas(
  $replicas as element(as:assignment)*,
  $hosts as xs:unsignedLong+,
  $hostnr as xs:integer,
  $forest-name as xs:string,
  $forestnr as xs:int,
  $append-numbering as xs:boolean) as element(as:assignment)*
{
  for $replica at $pos in $replicas
  let $default-replica-host := xdmp:host-name($hosts[($hostnr + $pos - 1) mod count($hosts) + 1])
  let $replica-name as xs:string := ($replica/as:forest-name[fn:string-length(fn:string(.)) > 0], fn:concat($forest-name, '-replica'))[1]
  let $replica-host-name := $replica/as:host-name[fn:string-length(fn:string(.)) > 0]
  let $replica-host-name :=
    if ($replica-host-name) then
      $replica-host-name
    else
      $default-replica-host
  return element { fn:node-name($replica) } {
      $replica/@*,
      <as:forest-name>{
        fn:string-join((
          $replica-name,
          if ($append-numbering) then
            fn:string-join(
              (fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)),
              "-"
            )
          else ()
        ), "-")
      }</as:forest-name>,
      <as:host-name>{$replica-host-name}</as:host-name>,
      $replica/node() except ($replica/as:forest-name, $replica/as:host-name)
  }
};

declare function setup:validate-forests-from-count(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string,
  $forests-per-host as xs:int)
{
  let $group-id := setup:get-group($db-config)
  for $forest-config in setup:get-database-forest-configs($import-config, $database-name)
  for $forest-name as xs:string in $forest-config/as:forest-name[fn:string-length(fn:string(.)) > 0]
  let $data-directory as xs:string? := ($forest-config/as:data-directory[fn:string-length(fn:string(.)) > 0], $db-config/db:forests/db:data-directory)[1]
  for $host at $hostnr in admin:group-get-host-ids(admin:get-configuration(), $group-id)
  for $forestnr in (1 to $forests-per-host)
  let $forest-name := fn:string-join(($database-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
  let $replica-names as xs:string* := $forest-config/as:replica-names/as:replica-name[fn:string-length(fn:string(.)) > 0]
  let $replicas := $import-config/as:assignments/as:assignment[as:forest-name = $replica-names]
  let $replica-names as xs:string* :=
    for $replica in $replicas
    let $replica-name as xs:string := ($replica/as:forest-name[fn:string-length(fn:string(.)) > 0], fn:concat($forest-name, '-replica'))[1]
    return
      fn:string-join(($replica-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
  return
    setup:validate-forest(
      $forest-name,
      $data-directory,
      $host,
      $replica-names)
};

declare function setup:get-database-forest-configs(
  $import-config as element(configuration),
  $db as xs:string) as element(as:assignment)*
{
  $import-config/as:assignments/as:assignment[
    as:forest-name = fn:data($import-config/db:databases/db:database[db:database-name = $db]/db:forests/db:forest-id/(@name|text()))]
};

declare function setup:create-forest(
  $forest-name as xs:string,
  $data-directory as xs:string?,
  $host-id as xs:unsignedLong?,
  $replicas as element(as:assignment)*) as item()*
{
  let $exists := xdmp:forests()[$forest-name = xdmp:forest-name(.)]
  let $host := ($host-id, $default-host)[1]
  let $admin-config := admin:get-configuration()
  let $admin-config :=
    if ($exists) then
      $admin-config
    else
      admin:forest-create($admin-config, $forest-name, $host, $data-directory)
  let $forest-id := admin:forest-get-id($admin-config, $forest-name)
  let $forest-replicas := admin:forest-get-replicas($admin-config, $forest-id)
  let $rep-log :=
    for $replica in $replicas
    let $replica-name := $replica/as:forest-name
    let $replica-dir := $replica/as:data-directory[fn:string-length(fn:string(.)) > 0]
    let $rep-exists := admin:forest-exists($admin-config, $replica-name)
    let $replica-host-name := $replica/as:host-name[fn:string-length(fn:string(.)) > 0]
    let $replica-host-id :=
      if ($replica-host-name) then xdmp:host($replica-host-name) else ()
    let $replica-host := ($replica-host-id, $default-host)[1]
    let $cfg :=
      if ($rep-exists) then
        $admin-config
      else
        admin:forest-create(
          $admin-config,
          $replica-name,
          $replica-host,
          $replica-dir)
    let $replica-id := admin:forest-get-id($cfg, $replica-name)
    let $cfg := admin:forest-set-failover-enable($cfg, $forest-id, fn:true())
    let $cfg := admin:forest-set-failover-enable($cfg, $replica-id, fn:true())
    let $rep-attached := fn:exists(
      for $r in $forest-replicas
      where $r eq $replica-id
      return $r
    )
    where fn:not($rep-attached)
    return (
      fn:string-join((
        "Forest ", $replica-name, " succesfully created",

        if ($replica-dir) then (" at ", $replica-dir)
        else (),
      
        if ($replica-host-name) then (" on ", $replica-host-name)
        else (),
        
        " as replica of ", $forest-name
      ), ""),
      xdmp:set($admin-config, admin:forest-add-replica($cfg, $forest-id, $replica-id))
    )
  return (
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
      if ($exists) then
        ("Forest ", $forest-name, " already exists, not recreated..")
      else
        ("Forest ", $forest-name, " succesfully created"),

      if ($data-directory) then (" at ", $data-directory)
      else (),
      
      if ($host) then (" on ", xdmp:host-name($host))
      else ()
    ), ""),
    
    $rep-log
  )
};

declare function setup:validate-forest(
  $forest-name as xs:string,
  $data-directory as xs:string?,
  $host-id as xs:unsignedLong?,
  $replica-names as xs:string*)
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
      else (),

      if ($replica-names) then
        let $actual := admin:forest-get-replicas($admin-config, $forest-id)
        let $expected :=
          for $replica-name in $replica-names
          return
            admin:forest-get-id($admin-config, $replica-name)
        return
          if ($actual = $expected) then ()
          else
            setup:validation-fail(fn:concat("Forest replica mismatch: ", fn:string-join($expected, ", "), " != ", fn:string-join($actual, ", ")))
      else ()
    )
  else
    setup:validation-fail(fn:concat("Forest missing: ", $forest-name))
};

declare function setup:create-databases($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  return
    if (xdmp:databases()[xdmp:database-name(.) = $database-name]) then
      fn:concat("Database ", $database-name, " already exists, not recreated..")
    else if ($database-name = 'filesystem') then
      fn:concat("Skipping creation of Database ", $database-name, "..")
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
    if (xdmp:databases()[xdmp:database-name(.) = ($database-name, 'filesystem')]) then ()
    else
      setup:validation-fail(fn:concat("Missing database: ", $database-name))
};

declare function setup:attach-forests($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  let $forests-per-host := $db-config/db:forests-per-host
  where fn:not($database-name = 'filesystem')
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
  where fn:not($database-name = 'filesystem')
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
    setup:attach-database-forest($database-name, fn:data($forest-ref/(@name|text())))
};

declare function setup:validate-attached-forests-by-config(
  $import-config as element(configuration),
  $db-config as element(db:database),
  $database-name as xs:string)
{
  for $forest-ref in $db-config/db:forests/db:forest-id
  return
    setup:validate-attached-database-forest($database-name, fn:data($forest-ref/(@name|text())))
};

declare function setup:attach-forests-by-count($db-config as element(db:database)) as item()*
{
  let $group-id := setup:get-group($db-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  for $host at $hostnr in admin:group-get-host-ids(admin:get-configuration(), $group-id)
  let $hostname := xdmp:host-name($host)
  for $forestnr in (1 to setup:get-forests-per-host-from-database-config($db-config))
  let $forest-name := fn:string-join(($database-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
  return
    setup:attach-database-forest($database-name, $forest-name)
};

declare function setup:validate-attached-forests-by-count($db-config as element(db:database))
{
  let $group-id := setup:get-group($db-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  for $host at $hostnr in admin:group-get-host-ids(admin:get-configuration(), $group-id)
  let $hostname := xdmp:host-name($host)
  for $forestnr in (1 to setup:get-forests-per-host-from-database-config($db-config))
  let $forest-name := fn:string-join(($database-name, fn:format-number(xs:integer($hostnr), "000"), xs:string($forestnr)), "-")
  return
    setup:validate-attached-database-forest($database-name, $forest-name)
};

declare function setup:attach-database-forest(
  $database-name as xs:string, $forest-name as xs:string) as item()*
{
  let $db := xdmp:database($database-name)
  let $forest := xdmp:forest($forest-name)
  let $admin-config := admin:get-configuration()

  (: don't detach forests first, they might be retired :)
  let $admin-config :=
    if (xdmp:database-forests(xdmp:database($database-name))[$forest-name = xdmp:forest-name(.)]) then
      $admin-config
    else
      admin:database-attach-forest($admin-config, $db, $forest)
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("Forest ", $forest-name, " succesfully attached to database ", $database-name)
  )
};

declare function setup:validate-attached-database-forest(
  $database-name as xs:string,
  $forest-name as xs:string)
{
  if (xdmp:database-forests(xdmp:database($database-name))[$forest-name = xdmp:forest-name(.)]) then ()
  else
    setup:validation-fail(fn:concat("Forest not attached to database: ", $forest-name, " => ", $database-name))
};

declare function setup:apply-database-settings($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  where fn:not($database-name = 'filesystem')
  return
  let $database := xdmp:database($database-name)
  let $apply-settings :=
    for $setting in $database-settings/*:setting
    let $value := fn:data(xdmp:value(fn:concat("$db-config/db:", $setting)))[fn:string(.) != '']
    let $min-version as xs:string? := $setting/@min-version
    where fn:exists($value)
    return
      if (fn:empty($min-version) or setup:at-least-version($min-version)) then
        xdmp:set(
          $admin-config,
          xdmp:value(fn:concat("admin:database-set-", $setting, "($admin-config, $database, $value)")))
      else ()
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
    let $database-name := setup:get-database-name-from-database-config($db-config)
    where fn:not($database-name = 'filesystem')
    return
    let $database := xdmp:database($database-name)
    for $setting in $database-settings/*:setting
    let $min-version as xs:string? := $setting/@min-version
    let $expected :=
      if (fn:empty($min-version) or setup:at-least-version($min-version)) then
        fn:data(xdmp:value(fn:concat("$db-config/db:", $setting)))
      else ()
    let $actual :=
      try
      {
        xdmp:value(fn:concat("admin:database-get-", $setting, "($admin-config, $database)"))
      }
      catch($ex)
      {
        if ($ex/error:code = "XDMP-UNDFUN") then ()
        else
          xdmp:rethrow()
      }
    where fn:exists($expected)
    return
      if ($expected = $actual) then ()
      else
        setup:validation-fail(fn:concat("database ", $setting, " mismatch: ", $expected, " != ", $actual))
};

declare function setup:configure-databases($import-config as element(configuration)) as item()*
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  where fn:not($database-name = 'filesystem')
  return
  let $database := xdmp:database($database-name)
  let $admin-config := admin:get-configuration()

  let $admin-config := setup:remove-existing-range-path-indexes($admin-config, $database)
  let $admin-config := setup:remove-existing-path-namespaces($admin-config, $database)

  let $admin-config := setup:add-word-lexicons($admin-config, $database, $db-config)
  let $admin-config := setup:add-fragment-roots($admin-config, $database, $db-config)
  let $admin-config := setup:add-fragment-parents($admin-config, $database, $db-config)
  let $admin-config := setup:config-word-query($admin-config, $database, $db-config)
  let $admin-config := setup:set-schema-database($admin-config, $db-config, $database)
  (:
    Changing the Security database is serious stuff. Roxy doesn't support this
  :)
  (:let $admin-config := setup:set-security-database($admin-config, $db-config, $database):)
  let $admin-config := setup:set-triggers-database($admin-config, $db-config, $database)
  let $admin-config := setup:add-range-element-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-range-element-attribute-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-path-namespaces($admin-config, $database, $db-config)
  let $admin-config := setup:add-range-path-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-geospatial-element-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-geospatial-element-attribute-pair-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-geospatial-element-pair-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-geospatial-element-child-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-fields($admin-config, $database, $db-config)
  let $admin-config := setup:apply-field-settings($admin-config, $database, $db-config)
  let $admin-config := setup:add-field-includes($admin-config, $database, $db-config)
  let $admin-config := setup:add-field-excludes($admin-config, $database, $db-config)
  let $admin-config := setup:add-field-word-lexicons($admin-config, $database, $db-config)
  let $admin-config := setup:add-range-field-indexes($admin-config, $database, $db-config)
  let $admin-config := setup:add-element-word-lexicons($admin-config, $database, $db-config)
  let $admin-config := setup:add-element-attribute-word-lexicons($admin-config, $database, $db-config)
  let $admin-config := setup:add-element-word-query-throughs($admin-config, $database, $db-config)
  let $admin-config := setup:add-phrase-throughs($admin-config, $database, $db-config)
  let $admin-config := setup:add-phrase-arounds($admin-config, $database, $db-config)

  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("Database ", $database-name, " configured succesfully.")
  )
};

declare function setup:validate-databases-indexes($import-config as element(configuration))
{
  for $db-config in setup:get-databases-from-config($import-config)
  let $database-name := setup:get-database-name-from-database-config($db-config)
  where fn:not($database-name = 'filesystem')
  return
  let $database := xdmp:database($database-name)
  let $admin-config := admin:get-configuration()
  return
  (
    setup:validate-word-lexicons($admin-config, $database, $db-config),
    setup:validate-fragment-roots($admin-config, $database, $db-config),
    setup:validate-fragment-parents($admin-config, $database, $db-config),
    setup:validate-word-query($admin-config, $database, $db-config),
    setup:validate-schema-database($admin-config, $db-config, $database),
    (:setup:validate-security-database($admin-config, $db-config, $database),:)
    setup:validate-triggers-database($admin-config, $db-config, $database),
    setup:validate-range-element-indexes($admin-config, $database, $db-config),
    setup:validate-range-element-attribute-indexes($admin-config, $database, $db-config),
    setup:validate-path-namespaces($admin-config, $database, $db-config),
    setup:validate-range-path-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-attribute-pair-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-pair-indexes($admin-config, $database, $db-config),
    setup:validate-geospatial-element-child-indexes($admin-config, $database, $db-config),
    setup:validate-fields($admin-config, $database, $db-config),
    setup:validate-range-field-indexes($admin-config, $database, $db-config),
    setup:validate-element-word-lexicons($admin-config, $database, $db-config),
    setup:validate-element-attribute-word-lexicons($admin-config, $database, $db-config),
    setup:validate-element-word-query-throughs($admin-config, $database, $db-config),
    setup:validate-phrase-throughs($admin-config, $database, $db-config),
    setup:validate-phrase-arounds($admin-config, $database, $db-config)
  )

};

declare function setup:remove-existing-fields(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $field as xs:string in admin:database-get-fields($admin-config, $database)/db:field-name[fn:not(. = "")]
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-field($admin-config, $database, $field)),
  $admin-config
};

declare function setup:add-fields(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-fields-R(
    setup:remove-existing-fields($admin-config, $database),
    $database,
    $db-config/db:fields/db:field[db:field-name and fn:not(db:field-name = "")]
  )
};

declare function setup:add-fields-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $field-configs as element(db:field)*) as element(configuration)
{
  if ($field-configs) then
    let $field := $field-configs[1]
    return
    setup:add-fields-R(
      if ($field/db:field-path) then
        if (setup:at-least-version("7.0-1")) then
          xdmp:eval(
            'import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
             declare namespace db = "http://marklogic.com/xdmp/database";
             declare variable $admin-config external;
             declare variable $database external;
             declare variable $field external;
             admin:database-add-field(
              $admin-config,
              $database,
              admin:database-path-field(
                $field/db:field-name,
                for $path in $field/db:field-path
                return
                  admin:database-field-path($path/db:path, ($path/weight, 1.0)[1]))
              )',
            (xs:QName("admin-config"), $admin-config,
             xs:QName("database"), $database,
             xs:QName("field"), $field),
            <options xmlns="xdmp:eval">
              <isolation>same-statement</isolation>
            </options>
          )
        else
          fn:error(
            xs:QName("VERSION_NOT_SUPPORTED"),
            fn:concat("MarkLogic ", xdmp:version(), " does not support path-based fields. Use 7.0-1 or higher."))
      else
        admin:database-add-field(
          $admin-config,
          $database,
          admin:database-field($field/db:field-name, $field/db:include-root)),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:validate-fields($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-fields($admin-config, $database)
  for $expected in $db-config/db:fields/db:field
  let $expected := element { fn:node-name($expected) } {
    $expected/@*,
    for $setting in $expected/*
    return
      if ($setting/self::db:value-searches) then
        <field-value-searches xmlns="http://marklogic.com/xdmp/database">{fn:string($setting)}</field-value-searches>
      else if ($setting/self::db:value-positions) then
        <field-value-positions xmlns="http://marklogic.com/xdmp/database">{fn:string($setting)}</field-value-positions>
      else $setting
  }
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched field: ", $expected/db:field-name))
};

declare function setup:apply-field-settings(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  let $apply-settings :=
    for $field in $db-config/db:fields/db:field
    let $field-name as xs:string := fn:string($field/db:field-name)
    for $setting in $field-settings/setting
    let $value := fn:data(xdmp:value(fn:concat("$field/db:", $setting)))
    let $min-version as xs:string? := $setting/@min-version
    where fn:exists($value) and (fn:empty($min-version) or setup:at-least-version($min-version))
    return
      xdmp:set(
        $admin-config,
        xdmp:value(fn:concat("admin:database-set-field-", fn:replace($setting, "^field-", ""), "($admin-config, $database, $field-name, $value)")))

  let $add-tokenizers :=
    if ($db-config/db:fields/db:field/db:tokenizer-overrides/db:tokenizer-override) then
      if (setup:at-least-version("7.0-0")) then
        for $field in $db-config/db:fields/db:field
        let $field-name as xs:string := $field/db:field-name
        let $overrides :=
          for $override in $field/db:tokenizer-overrides/db:tokenizer-override
          return
            xdmp:value("admin:database-tokenizer-override($override/db:character, $override/db:tokenizer-class)")
        where $overrides
        return
          xdmp:set(
            $admin-config,
            xdmp:value("admin:database-add-field-tokenizer-override($admin-config, $database, $field-name, $overrides)")
          )
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support field tokenizer-overrides. Use 7.0-0 or higher."))
    else ()

  return
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
    $db-config/db:fields/db:field[db:field-name and fn:not(db:field-name = "")])
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
            $e/db:localname/fn:string(.),
            ($e/db:weight, 1.0)[1],
            $e/db:attribute-namespace-uri,
            ($e/db:attribute-localname/fn:string(.), "")[1],
            ($e/db:attribute-value, "")[1])),
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
    $db-config/db:fields/db:field[db:field-name and fn:not(db:field-name = "")])
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
              $e/db:localname/fn:string(.))
          else
            xdmp:eval(
             'import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
              declare namespace db="http://marklogic.com/xdmp/database";
              declare variable $e external;

              admin:database-excluded-element(
                $e/db:namespace-uri,
                $e/db:localname/fn:string(.),
                ($e/db:attribute-namespace-uri, "")[1],
                ($e/db:attribute-localname/fn:string(.), "")[1],
                ($e/db:attribute-value, "")[1])',
              (xs:QName("e"), $e),
              <options xmlns="xdmp:eval">
                <isolation>same-statement</isolation>
              </options>)),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:add-field-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-field-word-lexicons-R(
    $admin-config,
    $database,
    $db-config/db:fields/db:field[db:field-name and fn:not(db:field-name = "")])
};

declare function setup:add-field-word-lexicons-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $field-configs as element(db:field)*) as element(configuration)
{
  if ($field-configs) then
    setup:add-field-word-lexicons-R(
      admin:database-add-field-word-lexicon(
        $admin-config,
        $database,
        $field-configs[1]/db:field-name,
        for $e in $field-configs[1]/db:word-lexicons/db:word-lexicon
        return
          admin:database-word-lexicon($e)),
      $database,
      fn:subsequence($field-configs, 2))
  else
    $admin-config
};

declare function setup:remove-existing-range-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-range-element-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-range-element-index($admin-config, $database, $index)),
  $admin-config
};

declare function setup:add-range-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-element-indexes-R(
    setup:remove-existing-range-element-indexes($admin-config, $database),
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
      admin:database-add-range-element-index($admin-config, $database,
        let $function := xdmp:function(xs:QName("admin:database-range-element-index"))
        return
          if (setup:at-least-version("6.0-1")) then
            xdmp:apply(
              $function,
              $index-configs[1]/db:scalar-type,
              $index-configs[1]/db:namespace-uri,
              $index-configs[1]/db:localname/fn:string(.),
              fn:string($index-configs[1]/db:collation[../db:scalar-type = 'string']),
              ($index-configs[1]/db:range-value-positions/xs:boolean(.), false())[1],
              ($index-configs[1]/db:invalid-values, "reject")[1]
            )
          else
            xdmp:apply(
              $function,
              $index-configs[1]/db:scalar-type,
              $index-configs[1]/db:namespace-uri,
              $index-configs[1]/db:localname/fn:string(.),
              fn:string($index-configs[1]/db:collation[../db:scalar-type = 'string']),
              ($index-configs[1]/db:range-value-positions/xs:boolean(.), false())[1]
            )
      ),
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
      setup:validation-fail(fn:concat("Missing range element index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-range-element-attribute-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-range-element-attribute-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-range-element-attribute-index($admin-config, $database, $index)),
  $admin-config
};

declare function setup:add-range-element-attribute-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-element-attribute-indexes-R(
    setup:remove-existing-range-element-attribute-indexes($admin-config, $database),
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
      admin:database-add-range-element-attribute-index($admin-config, $database,
        let $function := xdmp:function(xs:QName("admin:database-range-element-attribute-index"))
        return
          if (setup:at-least-version("6.0-1")) then
            xdmp:apply(
              $function,
              $index-configs[1]/db:scalar-type,
              $index-configs[1]/db:parent-namespace-uri,
              $index-configs[1]/db:parent-localname/fn:string(.),
              $index-configs[1]/db:namespace-uri,
              $index-configs[1]/db:localname/fn:string(.),
              fn:string($index-configs[1]/db:collation[../db:scalar-type = 'string']),
              ($index-configs[1]/db:range-value-positions/xs:boolean(.), false())[1],
              ($index-configs[1]/db:invalid-values, "reject")[1]
            )
          else
            xdmp:apply(
              $function,
              $index-configs[1]/db:scalar-type,
              $index-configs[1]/db:parent-namespace-uri,
              $index-configs[1]/db:parent-localname/fn:string(.),
              $index-configs[1]/db:namespace-uri,
              $index-configs[1]/db:localname/fn:string(.),
              fn:string($index-configs[1]/db:collation[../db:scalar-type = 'string']),
              ($index-configs[1]/db:range-value-positions/xs:boolean(.), false())[1]
            )
      ),
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
      setup:validation-fail(fn:concat("Missing range element attribute index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-path-namespaces(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  (: wrap in try catch because this function is new to 6.0 and will fail in older version of ML :)
  try
  {
    xdmp:eval('
      import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
      declare variable $database external;
      declare variable $admin-config external;
      let $remove-existing-indexes :=
        for $index at $i in admin:database-get-path-namespaces($admin-config, $database)
        return
          xdmp:set($admin-config, admin:database-delete-path-namespace($admin-config, $database, $index))
      return
        $admin-config',
      (xs:QName("database"), $database,
       xs:QName("admin-config"), $admin-config))
  }
  catch($ex)
  {
    if ($ex/error:code = "XDMP-UNDFUN") then $admin-config
    else if ($ex/error:code = "ADMIN-PATHNAMESPACEINUSE" and fn:not(setup:at-least-version("6.0-2"))) then
      fn:error(xs:QName("VERSION_NOT_SUPPORTED"), "Roxy does not support path namespaces for this version of MarkLogic. Use 6.0-2 or later.")
    else
      xdmp:rethrow()
  }
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

declare function setup:remove-existing-range-path-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  (: wrap in try catch because this function is new to 6.0 and will fail in older version of ML :)
  try
  {
    xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
        declare variable $database external;
        declare variable $admin-config external;
        let $remove-existing-indexes :=
          for $index in admin:database-get-range-path-indexes($admin-config, $database)
          return
            xdmp:set(
              $admin-config,
              admin:database-delete-range-path-index($admin-config, $database, $index))
        return
          $admin-config',
        (xs:QName("database"), $database,
         xs:QName("admin-config"), $admin-config))
  }
  catch($ex)
  {
    if ($ex/error:code = "XDMP-UNDFUN") then $admin-config
    else
      xdmp:rethrow()
  }
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
  let $expected :=
    xdmp:eval('
      import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
      declare namespace db="http://marklogic.com/xdmp/database";
      declare variable $database external;
      declare variable $x external;

      admin:database-range-path-index(
       $database,
       $x/db:scalar-type,
       $x/db:path-expression,
       fn:string($x/db:collation[../db:scalar-type = "string"]),
       $x/db:range-value-positions,
       $x/db:invalid-values)',
      (xs:QName("database"), $database,
       xs:QName("x"), $expected))
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Missing range path index: ", $expected/db:path-expression))
};

declare function setup:remove-existing-element-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $lexicon in admin:database-get-element-word-lexicons($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-element-word-lexicon($admin-config, $database, $lexicon)),
  $admin-config
};

declare function setup:add-element-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-element-word-lexicons-R(
    setup:remove-existing-element-word-lexicons($admin-config, $database),
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

declare function setup:validate-element-word-lexicons($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-element-word-lexicons($admin-config, $database)
  for $expected in $db-config/db:element-word-lexicons/db:element-word-lexicon
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched element word lexicon: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-element-attribute-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $lexicon in admin:database-get-element-attribute-word-lexicons($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-element-attribute-word-lexicon($admin-config, $database, $lexicon)),
  $admin-config
};

declare function setup:add-element-attribute-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-element-attribute-word-lexicons-R(
    setup:remove-existing-element-attribute-word-lexicons($admin-config, $database),
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

declare function setup:validate-element-attribute-word-lexicons($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-element-attribute-word-lexicons($admin-config, $database)
  for $expected in $db-config/db:element-attribute-word-lexicons/db:element-attribute-word-lexicon
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched element attribute word lexicon: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-element-word-query-throughs(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $query-through in admin:database-get-element-word-query-throughs($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-element-word-query-through($admin-config, $database, $query-through)),
  $admin-config
};

declare function setup:add-element-word-query-throughs(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-element-word-query-throughs-R(
    setup:remove-existing-element-word-query-throughs($admin-config, $database),
    $database,
    $db-config/db:element-word-query-throughs/db:element-word-query-through)
};

declare function setup:add-element-word-query-throughs-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $query-throughs as element(db:element-word-query-through)*) as element(configuration)
{
  if ($query-throughs) then
    setup:add-element-word-query-throughs-R(
      admin:database-add-element-word-query-through($admin-config, $database, $query-throughs[1]),
      $database,
      fn:subsequence($query-throughs, 2))
  else
    $admin-config
};

declare function setup:validate-element-word-query-throughs($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-element-word-query-throughs($admin-config, $database)
  for $expected in $db-config/db:element-word-query-throughs/db:element-word-query-through
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched element word query through: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-phrase-throughs(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $query-through in admin:database-get-phrase-throughs($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-phrase-through($admin-config, $database, $query-through)),
  $admin-config
};

declare function setup:add-phrase-throughs(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-phrase-throughs-R(
    setup:remove-existing-phrase-throughs($admin-config, $database),
    $database,
    $db-config/db:phrase-throughs/db:phrase-through)
};

declare function setup:add-phrase-throughs-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $phrase-throughs as element(db:phrase-through)*) as element(configuration)
{
  if ($phrase-throughs) then
    setup:add-phrase-throughs-R(
      admin:database-add-phrase-through($admin-config, $database, $phrase-throughs[1]),
      $database,
      fn:subsequence($phrase-throughs, 2))
  else
    $admin-config
};

declare function setup:validate-phrase-throughs($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-phrase-throughs($admin-config, $database)
  for $expected in $db-config/db:phrase-throughs/db:phrase-through
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched phrase through: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-phrase-arounds(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $phrase-around in admin:database-get-phrase-arounds($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-phrase-around($admin-config, $database, $phrase-around)),
  $admin-config
};

declare function setup:add-phrase-arounds(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-phrase-arounds-R(
    setup:remove-existing-phrase-arounds($admin-config, $database),
    $database,
    $db-config/db:phrase-arounds/db:phrase-around)
};

declare function setup:add-phrase-arounds-R(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $phrase-arounds as element(db:phrase-around)*) as element(configuration)
{
  if ($phrase-arounds) then
    setup:add-phrase-arounds-R(
      admin:database-add-phrase-around($admin-config, $database, $phrase-arounds[1]),
      $database,
      fn:subsequence($phrase-arounds, 2))
  else
    $admin-config
};

declare function setup:validate-phrase-arounds($admin-config, $database, $db-config)
{
  let $existing := admin:database-get-phrase-arounds($admin-config, $database)
  for $expected in $db-config/db:phrase-arounds/db:phrase-around
  return
    if ($existing[fn:deep-equal(., $expected)]) then ()
    else
      setup:validation-fail(fn:concat("Database mismatched phrase around: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-range-field-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  (: wrap in try catch because this function is new to 5.0 and will fail in older version of ML :)
  try
  {
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
       xs:QName("database"), $database))
  }
  catch($ex)
  {
    if ($ex/error:code = "XDMP-UNDFUN") then $admin-config
    else
      xdmp:rethrow()
  }
};


declare function setup:add-range-field-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-range-field-indexes-R(
    setup:remove-existing-range-field-indexes($admin-config, $database),
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

declare function setup:remove-existing-geospatial-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-geospatial-element-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-geospatial-element-index($admin-config, $database, $index)),
  $admin-config
};

declare function setup:validate-range-field-indexes($admin-config, $database, $db-config)
{
  try
  {
    let $existing :=
      xdmp:eval('
        import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

        declare namespace db="http://marklogic.com/xdmp/database";

        declare variable $admin-config external;
        declare variable $database external;

        admin:database-get-range-field-indexes($admin-config, $database)',
        (xs:QName("admin-config"), $admin-config,
         xs:QName("database"), $database))
    for $expected in $db-config/db:range-field-indexes/db:range-field-index
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Database mismatched range field index: ", $expected/db:field-name))
  }
  catch($ex)
  {
    if ($ex/error:code = "XDMP-UNDFUN") then $admin-config
    else
      xdmp:rethrow()
  }
};

declare function setup:add-geospatial-element-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-indexes-R(
    setup:remove-existing-geospatial-element-indexes($admin-config, $database),
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
      setup:validation-fail(fn:concat("Missing geospatial element index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-geospatial-element-attribute-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-geospatial-element-attribute-pair-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-geospatial-element-attribute-pair-index($admin-config, $database, $index)),
  $admin-config
};


declare function setup:add-geospatial-element-attribute-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-attribute-pair-indexes-R(
    setup:remove-existing-geospatial-element-attribute-pair-indexes($admin-config, $database),
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
      setup:validation-fail(fn:concat("Missing geospatial element attribute pair index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-geospatial-element-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-geospatial-element-pair-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-geospatial-element-pair-index($admin-config, $database, $index)),
  $admin-config
};

declare function setup:add-geospatial-element-pair-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-pair-indexes-R(
    setup:remove-existing-geospatial-element-pair-indexes($admin-config, $database),
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
      setup:validation-fail(fn:concat("Missing geospatial element pair index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-geospatial-element-child-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $index in admin:database-get-geospatial-element-child-indexes($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-geospatial-element-child-index($admin-config, $database, $index)),
  $admin-config
};

declare function setup:add-geospatial-element-child-indexes(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-geospatial-element-child-indexes-R(
    setup:remove-existing-geospatial-element-child-indexes($admin-config, $database),
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
      setup:validation-fail(fn:concat("Missing geospatial element child index: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $lexicon in admin:database-get-word-lexicons($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-word-lexicon($admin-config, $database, $lexicon)),
  $admin-config
};

declare function setup:add-word-lexicons(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-word-lexicons-R(
    setup:remove-existing-word-lexicons($admin-config, $database),
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
      admin:database-add-word-lexicon(
        $admin-config,
        $database,
        admin:database-word-lexicon($collations[1])),
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

declare function setup:remove-existing-fragment-roots(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $root in admin:database-get-fragment-roots($admin-config, $database)
  return
   xdmp:set($admin-config, admin:database-delete-fragment-root($admin-config, $database, $root)),
  $admin-config
};

declare function setup:add-fragment-roots(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-fragment-roots-R(
    setup:remove-existing-fragment-roots($admin-config, $database),
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
          $fragment-roots[1]/db:localname/fn:string(.))),
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
    if ($existing[db:namespace-uri = $expected/db:namespace-uri and db:localname/fn:string(.) = $expected/db:localname/fn:string(.)]) then ()
    else
      setup:validation-fail(fn:concat("Missing fragment root: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-fragment-parents(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $parent in admin:database-get-fragment-parents($admin-config, $database)
  return
    xdmp:set($admin-config, admin:database-delete-fragment-parent($admin-config, $database, $parent)),
  $admin-config
};

declare function setup:add-fragment-parents(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  setup:add-fragment-parents-R(
    setup:remove-existing-fragment-parents($admin-config, $database),
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
          $fragment-parents[1]/db:localname/fn:string(.))),
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
    if ($existing[db:namespace-uri = $expected/db:namespace-uri and db:localname/fn:string(.) = $expected/db:localname/fn:string(.)]) then ()
    else
      setup:validation-fail(fn:concat("Missing fragment root: ", $expected/db:localname/fn:string(.)))
};

declare function setup:remove-existing-word-query-included-elements(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $element in admin:database-get-word-query-included-elements($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-word-query-included-element(
        $admin-config,
        $database,
        $element)),
  $admin-config
};

declare function setup:remove-existing-word-query-excluded-elements(
  $admin-config as element(configuration),
  $database as xs:unsignedLong) as element(configuration)
{
  for $element in admin:database-get-word-query-excluded-elements($admin-config, $database)
  return
    xdmp:set(
      $admin-config,
      admin:database-delete-word-query-excluded-element(
        $admin-config,
        $database,
        $element)),
  $admin-config
};

declare function setup:config-word-query(
  $admin-config as element(configuration),
  $database as xs:unsignedLong,
  $db-config as element(db:database)) as element(configuration)
{
  let $empty-field := $db-config/db:fields/db:field[fn:empty(db:field-name) or db:field-name = ""]
  return
  (
    xdmp:set($admin-config, setup:remove-existing-word-query-included-elements($admin-config, $database)),
    for $element in $empty-field/db:included-elements/db:included-element
    return
      xdmp:set(
        $admin-config,
        admin:database-add-word-query-included-element(
          $admin-config,
          $database,
          $element)),

    xdmp:set($admin-config, setup:remove-existing-word-query-excluded-elements($admin-config, $database)),
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
  let $empty-field := $db-config/db:fields/db:field[fn:empty(db:field-name) or db:field-name = ""]
  return
  (
    let $existing := admin:database-get-word-query-included-elements($admin-config, $database)
    for $expected in $empty-field/db:included-elements/db:included-element
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Missing word query included element: ", $expected/db:localname/fn:string(.))),

    let $existing := admin:database-get-word-query-excluded-elements($admin-config, $database)
    for $expected in $empty-field/db:excluded-elements/db:excluded-element
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Missing word query excluded element: ", $expected/db:localname/fn:string(.))),

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

declare function setup:set-triggers-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  admin:database-set-triggers-database(
    $admin-config,
    $database,
    setup:get-triggers-database($db-config))
};

declare function setup:validate-triggers-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-triggers-database($admin-config, $database)
  let $expected := setup:get-triggers-database($db-config)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Triggers database mismatch! ", $expected, " != ", $actual))
};

declare function setup:set-schema-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  admin:database-set-schema-database(
    $admin-config,
    $database,
    setup:get-schema-database($db-config))
};

declare function setup:validate-schema-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-schema-database($admin-config, $database)
  let $expected := setup:get-schema-database($db-config)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Schema database mismatch! ", $expected, " != ", $actual))
};

declare function setup:set-security-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong) as element(configuration)
{
  admin:database-set-security-database(
    $admin-config,
    $database,
    setup:get-security-database($db-config))
};

declare function setup:validate-security-database(
  $admin-config as element(configuration),
  $db-config as element(db:database),
  $database as xs:unsignedLong)
{
  let $actual := admin:database-get-security-database($admin-config, $database)
  let $expected := setup:get-security-database($db-config)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Security database mismatch! ", $expected, " != ", $actual))
};

declare function setup:create-groups(
  $import-config as element(configuration)) as item()*
{
  for $group in $import-config/gr:groups/gr:group/gr:group-name[fn:not(. = "Default")]
  return
    setup:create-group($group)
};

declare function setup:create-group(
  $group as xs:string) as item()*
{
  let $admin-config := admin:get-configuration()
  let $_ :=
    if (admin:group-exists($admin-config, $group)) then ()
    else
      xdmp:set($admin-config, admin:group-create($admin-config, $group))
  
  (: Make sure App-Services and Manage are available in the new group in case the host we use Roxy against is assigned to it! :)
  let $group-id := admin:group-get-id($admin-config, $group)
  let $appservices-id := xdmp:server("App-Services")[1]
  let $appservices-port := admin:appserver-get-port($admin-config, $appservices-id)
  let $manage-id := xdmp:server("Manage")[1]
  let $manage-port := admin:appserver-get-port($admin-config, $manage-id)
  let $_ :=
    if (admin:appserver-exists($admin-config, $group-id, "App-Services")) then ()
    else
      xdmp:set($admin-config,
        admin:appserver-copy($admin-config, $appservices-id, $group-id, "App-Services", $appservices-port))
  let $_ :=
    if (admin:appserver-exists($admin-config, $group-id, "Manage")) then ()
    else
      xdmp:set($admin-config,
        admin:appserver-copy($admin-config, $manage-id, $group-id, "Manage", $manage-port))
  
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    setup:add-rollback("groups", $group),
    fn:concat("Group ", $group, " succesfully created.")
  )
};

declare function setup:validate-groups(
  $import-config as element(configuration)) as item()*
{
  for $group in $import-config/gr:groups/gr:group/gr:group-name[fn:not(. = "Default")]
  return
    setup:validate-group($group)
};

declare function setup:validate-group(
  $group as xs:string) as item()*
{
  let $existing-groups as xs:string* :=
    for $g in xdmp:groups()
    return
      xdmp:group-name($g)
  return
    if ($existing-groups[. = $group]) then ()
    else
      setup:validation-fail(fn:concat("Missing Group: ", $group))
};

declare function setup:configure-groups($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  for $group-config in $import-config/gr:groups/gr:group
  let $group-name := $group-config/gr:group-name
  let $group-id := xdmp:group($group-name)
  let $apply-settings :=
    for $setting in $group-settings/*:setting
    let $setting-test :=
      if ($setting/@accept-blank = "true") then
        ""
      else
        "[fn:string-length(fn:string(.)) > 0]"
    let $value :=
      if ($setting/@value) then
        xdmp:value($setting/@value)
      else
        fn:data(xdmp:value(fn:concat("$group-config/gr:", $setting, $setting-test)))
    let $min-version as xs:string? := $setting/@min-version
    where (fn:exists($value))
    return
      if (fn:empty($min-version) or setup:at-least-version($min-version)) then
        xdmp:set($admin-config,
          xdmp:value(fn:concat("admin:group-set-", $setting, "($admin-config, $group-id, $value)")))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher."))
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),

    fn:concat("Group ", $group-name, " settings applied succesfully.")
  )
};

declare function setup:validate-groups-settings($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $settings := $group-settings
  for $group-config in $import-config/gr:groups/gr:group
  let $group-name := $group-config/gr:group-name
  let $group-id := xdmp:group($group-name)

  for $setting in $settings/*:setting
  let $setting-test :=
    if ($setting/@accept-blank = "true") then
      ""
    else
      "[fn:string-length(fn:string(.)) > 0]"
  let $expected :=
    if ($setting/@value) then
      xdmp:value($setting/@value)
    else
      fn:data(xdmp:value(fn:concat("$group-config/gr:", $setting, $setting-test)))
  let $min-version as xs:string? := $setting/@min-version
  where (fn:exists($expected))
  return
    if (fn:empty($min-version) or setup:at-least-version($min-version)) then
      let $actual := xdmp:value(fn:concat("admin:group-get-", $setting, "($admin-config, $group-id)"))
      return
        if ($expected = $actual) then ()
        else
          setup:validation-fail(fn:concat("Group ", $setting, " mismatch: ", $expected, " != ", $actual))
    else
      fn:error(
        xs:QName("VERSION_NOT_SUPPORTED"),
        fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher."))
};

declare function setup:configure-hosts($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  for $host-config in $import-config/ho:hosts/ho:host
  let $host-name := $host-config/ho:host-name
  let $host-id := xdmp:host($host-name)
  let $apply-settings :=
    for $setting in $host-settings/*:setting
    let $setting-test :=
      if ($setting/@accept-blank = "true") then
        ""
      else
        "[fn:string-length(fn:string(.)) > 0]"
    let $value :=
      if ($setting/@value) then
        xdmp:value($setting/@value)
      else
        fn:data(xdmp:value(fn:concat("$host-config/ho:", $setting, $setting-test)))[fn:string(.) != '']
    let $min-version as xs:string? := $setting/@min-version
    where (fn:exists($value))
    return
      if (fn:empty($min-version) or setup:at-least-version($min-version)) then
        xdmp:set($admin-config,
          xdmp:value(fn:concat("admin:host-set-", $setting, "($admin-config, $host-id, $value)")))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher."))
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),

    fn:concat("Host ", $host-name, " settings applied succesfully.")
  )
};

declare function setup:validate-hosts-settings($import-config as element(configuration)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $settings := $host-settings
  for $host-config in $import-config/ho:hosts/ho:host
  let $host-name := $host-config/ho:host-name
  let $host-id := xdmp:host($host-name)

  for $setting in $settings/*:setting
  let $setting-test :=
    if ($setting/@accept-blank = "true") then
      ""
    else
      "[fn:string-length(fn:string(.)) > 0]"
  let $expected :=
    if ($setting/@value) then
      xdmp:value($setting/@value)
    else
      fn:data(xdmp:value(fn:concat("$host-config/ho:", $setting, $setting-test)))
  let $min-version as xs:string? := $setting/@min-version
  where (fn:exists($expected))
  return
    if (fn:empty($min-version) or setup:at-least-version($min-version)) then
      let $actual := xdmp:value(fn:concat("admin:host-get-", $setting, "($admin-config, $host-id)"))
      return
        if ($expected = $actual) then ()
        else
          setup:validation-fail(fn:concat("Host ", $setting, " mismatch: ", $expected, " != ", $actual))
    else
      fn:error(
        xs:QName("VERSION_NOT_SUPPORTED"),
        fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher."))
};

declare function setup:create-appservers(
  $import-config as element(configuration)) as item()*
{
  for $http-config in setup:get-http-appservers-from-config($import-config)
  return
    setup:create-appserver($http-config),

  for $xdbc-config in $import-config/gr:groups/gr:group/gr:xdbc-servers/gr:xdbc-server
  return
    setup:create-xdbcserver($xdbc-config),

  for $odbc-config in $import-config/gr:groups/gr:group/gr:odbc-servers/gr:odbc-server
  return
    setup:create-odbcserver($odbc-config)
};

(: Allow one HTTP app server to import most of its config from another :)
declare function setup:get-http-appservers-from-config(
  $import-config as element(configuration)) as element(gr:http-server)*
{
  for $server in $import-config/gr:groups/gr:group/gr:http-servers/gr:http-server
  return
    if (fn:exists($server/@import)) then
      let $imported-http := $import-config/gr:groups/gr:group/gr:http-servers/gr:http-server[gr:http-server-name eq $server/@import]
      return
        element gr:http-server
        {
          $server/@*[fn:not(fn:local-name(.) = "import")],
          $imported-http/@*[fn:not(fn:local-name(.) = $server/@*/fn:local-name(.))],
          $server/*,
          let $ignore := $server/*/fn:node-name(.)
          return
            $imported-http/*[fn:not(fn:node-name(.) = $ignore)]
        }
    else
      $server
};

declare function setup:validate-appservers(
  $import-config as element(configuration)) as item()*
{
  for $http-config in setup:get-http-appservers-from-config($import-config)
  return
    setup:validate-appserver($http-config),

  for $xdbc-config in $import-config/gr:groups/gr:group/gr:xdbc-servers/gr:xdbc-server
  return
    setup:validate-xdbcserver($xdbc-config),

  for $odbc-config in $import-config/gr:groups/gr:group/gr:odbc-servers/gr:odbc-server
  return
    setup:validate-odbcserver($odbc-config)
};

declare function setup:create-appserver(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then
      fn:concat("HTTP Server ", $server-name, " already exists, not recreated..")
    else
      let $root := ($server-config/gr:root[fn:string-length(fn:string(.)) > 0], "/")[1]
      let $port := xs:unsignedLong($server-config/gr:port)
      let $database := setup:get-appserver-content-database($server-config)
      let $modules := setup:get-appserver-modules-database($server-config)
      let $group-id := setup:get-group($server-config)
      let $admin-config := admin:get-configuration()
      let $admin-config :=
        if (xs:boolean($server-config/gr:webDAV)) then
          (: Note: database id is stored as modules for webdav servers, allowing both in ml-config :)
          admin:webdav-server-create(
            $admin-config,
            $group-id,
            $server-name,
            $root,
            $port,
            ($database[. != 0], $modules)[1])
        else
          admin:http-server-create(
            $admin-config,
            $group-id,
            $server-name,
            $root,
            $port,
            $modules,
            $database)
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        setup:add-rollback("http-servers", $server-config),
        fn:concat("HTTP Server ", $server-name, " succesfully created.")
      )
};

declare function setup:validate-appserver(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing HTTP server: ", $server-name))
};

declare function setup:create-odbcserver(
  $server-config as element(gr:odbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:odbc-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then
      fn:concat("ODBC Server ", $server-name, " already exists, not recreated..")
    else
      let $group-id := setup:get-group($server-config)
      (: wrap in try catch because this function is new to 6.0 and will fail in older version of ML :)
      let $admin-config := admin:get-configuration()
      let $admin-config :=
        try
        {
          xdmp:eval('
            import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
            declare variable $admin-config external;
            declare variable $root external;
            declare variable $port external;
            declare variable $content-db external;
            declare variable $group-id external;
            declare variable $server-name external;
            declare variable $modules-db external;
            admin:odbc-server-create(
              admin:get-configuration(),
              $group-id,
              $server-name,
              $root,
              $port,
              $modules-db,
              $content-db)',
            (xs:QName("admin-config"), $admin-config,
             xs:QName("root"), ($server-config/gr:root[fn:string-length(fn:string(.)) > 0], "/")[1],
             xs:QName("port"), xs:unsignedLong($server-config/gr:port),
             xs:QName("content-db"), setup:get-appserver-content-database($server-config),
             xs:QName("group-id"), $group-id,
             xs:QName("server-name"), $server-name,
             xs:QName("modules-db"), setup:get-appserver-modules-database($server-config)))
        }
        catch($ex)
        {
          if ($ex/error:code = "XDMP-UNDFUN" and fn:not(setup:at-least-version("6.0-2"))) then
            fn:error(xs:QName("VERSION_NOT_SUPPORTED"), "Roxy does not support ODBC application servers for this version of MarkLogic. Use 6.0-2 or later.")
          else
            xdmp:rethrow()
        }
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        setup:add-rollback("odbc-servers", $server-config),
        fn:concat("ODBC Server ", $server-name, " succesfully created.")
      )
};

declare function setup:validate-odbcserver(
  $server-config as element(gr:odbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:odbc-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing ODBC server: ", $server-name))
};

declare function setup:create-xdbcserver(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then
      fn:concat("XDBC Server ", $server-name, " already exists, not recreated..")
    else
      let $group-id := setup:get-group($server-config)
      let $admin-config :=
        admin:xdbc-server-create(
          admin:get-configuration(),
          $group-id,
          $server-name,
          ($server-config/gr:root[fn:string-length(fn:string(.)) > 0], "/")[1],
          xs:unsignedLong($server-config/gr:port),
          setup:get-appserver-modules-database($server-config),
          setup:get-appserver-content-database($server-config))
      return
      (
        if (admin:save-configuration-without-restart($admin-config)) then
          xdmp:set($restart-needed, fn:true())
        else (),
        setup:add-rollback("xdbc-servers", $server-config),
        fn:concat("XDBC Server ", $server-name, " succesfully created.")
      )
};

declare function setup:validate-xdbcserver(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(fn:string(.)) > 0]
  return
    if (xdmp:servers()[xdmp:server-name(.) = $server-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing XDBC server: ", $server-name))
};

declare function setup:apply-appservers-settings(
  $import-config as element(configuration)) as item()*
{
  for $http-config in setup:get-http-appservers-from-config($import-config)
  return
    setup:configure-http-server($http-config),

  for $xdbc-config in $import-config/gr:groups/gr:group/gr:xdbc-servers/gr:xdbc-server
  return
    setup:configure-xdbc-server($xdbc-config),

  for $odbc-config in $import-config/gr:groups/gr:group/gr:odbc-servers/gr:odbc-server
  return
    setup:configure-odbc-server($odbc-config),

  for $task-config in $import-config/gr:groups/gr:group/gr:task-server
  return
    setup:configure-task-server($task-config)
};

declare function setup:validate-appservers-settings(
  $import-config as element(configuration)) as item()*
{
  for $http-config in setup:get-http-appservers-from-config($import-config)
  return
    setup:validate-http-server($http-config),

  for $xdbc-config in $import-config/gr:groups/gr:group/gr:xdbc-servers/gr:xdbc-server
  return
    setup:validate-xdbc-server($xdbc-config),

  for $odbc-config in $import-config/gr:groups/gr:group/gr:odbc-servers/gr:odbc-server
  return
    setup:validate-odbc-server($odbc-config),

  for $task-config in $import-config/gr:groups/gr:group/gr:task-server
  return
    setup:validate-task-server($task-config)
};

declare function setup:configure-http-server(
  $server-config as element(gr:http-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:http-server-name[fn:string-length(fn:string(.)) > 0]
  let $admin-config := setup:configure-server($server-config, xdmp:server($server-name), if (xs:boolean($server-config/gr:webDAV)) then $webdav-server-settings else $http-server-settings)
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("HTTP Server ", $server-name, " settings applied succesfully.")
  )
};

declare function setup:validate-http-server(
  $server-config as element(gr:http-server)) as item()*
{
  setup:validate-server(
    $server-config,
    xdmp:server($server-config/gr:http-server-name[fn:string-length(fn:string(.)) > 0]),
    if ($server-config/gr:webDAV = fn:true()) then
      $webdav-server-settings
    else
      $http-server-settings)
};

declare function setup:configure-xdbc-server(
  $server-config as element(gr:xdbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:xdbc-server-name[fn:string-length(fn:string(.)) > 0]
  let $admin-config := setup:configure-server($server-config, xdmp:server($server-name), $xdbc-server-settings)
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
  setup:validate-server(
    $server-config,
    xdmp:server($server-config/gr:xdbc-server-name[fn:string-length(fn:string(.)) > 0]),
    $xdbc-server-settings)
};

declare function setup:configure-odbc-server(
  $server-config as element(gr:odbc-server)) as item()*
{
  let $server-name as xs:string? := $server-config/gr:odbc-server-name[fn:string-length(fn:string(.)) > 0]
  let $admin-config := setup:configure-server($server-config, xdmp:server($server-name), $odbc-server-settings)
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    fn:concat("ODBC Server ", $server-name, " settings applied succesfully.")
  )
};

declare function setup:validate-odbc-server(
  $server-config as element(gr:odbc-server)) as item()*
{
  setup:validate-server(
    $server-config,
    xdmp:server($server-config/gr:odbc-server-name[fn:string-length(fn:string(.)) > 0]),
    $odbc-server-settings)
};

declare function setup:configure-task-server(
  $server-config as element(gr:task-server)) as item()*
{
  let $admin-config := admin:get-configuration()
  let $group-id := setup:get-group($server-config)
  let $apply-settings :=
    for $setting in $task-server-settings/*:setting
    let $value := fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting)))
    where fn:exists($value)
    return
      xdmp:set(
        $admin-config,
        xdmp:value(
          fn:concat("admin:taskserver-set-", $setting, "($admin-config, $group-id, $value)")))
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
  let $group-id := setup:get-group($server-config)
  for $setting in $task-server-settings/*:setting
  let $expected := fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting)))
  let $actual := xdmp:value(fn:concat("admin:taskserver-get-", $setting, "($admin-config, $group-id)"))
  where fn:exists($expected)
  return
    if ($expected = $actual) then ()
    else
      setup:validation-fail(fn:concat("Task Server ", $setting, " mismatch: ", $expected, " != ", $actual))
};

declare function setup:get-appserver-privilege(
  $server-config as element()) as xs:unsignedLong
{
  let $privilege as xs:string? := $server-config/gr:privilege[fn:string-length(fn:string(.)) > 0]/fn:string(.)
  return
    if ($privilege = "0") then 0
    else if ($privilege) then
      let $id as xs:unsignedLong? := setup:get-privilege-by-name($privilege)/sec:privilege-id
      return
        if ($id) then $id
        else
          fn:error(
            xs:QName("INVALID-PRIVILEGE"),
            fn:concat(
              "Invalid privilege '",
              $privilege))
    else 0
};

declare function setup:configure-server(
  $server-config as element(),
  $server-id as xs:unsignedLong,
  $settings as element(settings)) as element(configuration)
{
  let $admin-config := admin:get-configuration()
  let $apply-settings :=
    for $setting in $settings/*:setting
    let $setting-test :=
      if ($setting/@accept-blank = "true") then
        ""
      else
        "[fn:string-length(fn:string(.)) > 0]"
    let $min-version as xs:string? := $setting/@min-version
    let $version-ok := fn:empty($min-version) or setup:at-least-version($min-version)
    let $if :=
      if ($setting/@if) then
        xdmp:value($setting/@if)
      else
        fn:true()
    let $value :=
      if ($setting/@value and $if and $version-ok) then
        xdmp:value($setting/@value)
      else
        fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting, $setting-test)))[fn:string(.) != '']
    where ($if and fn:exists($value))
    return
      if ($version-ok) then
        xdmp:set($admin-config,
          xdmp:value(fn:concat("admin:appserver-set-", $setting, "($admin-config, $server-id, $value)")))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher."))

  let $namespaces := $server-config/gr:namespaces/gr:namespace
  let $admin-config :=
    if ($namespaces) then
      let $old-ns := admin:appserver-get-namespaces($admin-config, $server-id)
      let $config :=
        (: First delete any namespace that matches the prefix, prefix must be unique :)
        admin:appserver-delete-namespace(
          $admin-config,
          $server-id,
          for $ns in $namespaces
          let $same-prefix :=
            $old-ns[gr:prefix eq $ns/gr:prefix][gr:namespace-uri ne $ns/gr:namespace-uri]
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

  let $schemas := $server-config/gr:schemas/gr:schema
  let $admin-config :=
    if ($schemas) then
      let $old-schemas := admin:appserver-get-schemas($admin-config, $server-id)
      let $config :=
        (: First delete any schema that matches the namespace, namespace must be unique :)
        admin:appserver-delete-schema(
          $admin-config,
          $server-id,
          for $schema in $schemas
          return
            $old-schemas[gr:namespace-uri eq $schema/gr:namespace-uri][gr:schema-location ne $schema/gr:schema-location])
      return
        (: Then add in any schema whose namespace isn't already defined :)
        admin:appserver-add-schema(
          $config,
          $server-id,
          for $schema in $schemas
          return
            if ($old-schemas[gr:namespace-uri eq $schema/gr:namespace-uri][gr:schema-location eq $schema/gr:schema-location]) then ()
            else
              $schema)
    else
      $admin-config

  let $admin-config :=
    let $external-security as xs:string? := $server-config/gr:external-security/@name
    return
      if ($external-security) then
        try {
          xdmp:eval('
            import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

            declare namespace gr="http://marklogic.com/xdmp/group";

            declare variable $admin-config external;
            declare variable $server-id external;
            declare variable $external-security external;
            declare variable $server-config external;

            admin:appserver-set-external-security(
              $admin-config,
              $server-id,
              $external-security,
              xs:boolean($server-config/gr:internal-security),
              fn:string($server-config/gr:authentication))
          ',
          (
            xs:QName("admin-config"), $admin-config,
            xs:QName("server-id"), $server-id,
            xs:QName("external-security"), $external-security,
            xs:QName("server-config"), $server-config
          ))
        }
        catch($ex) {
          if ($ex/error:code = "XDMP-UNDFUN" and fn:not(setup:at-least-version("7.0-0"))) then
            fn:error(
              xs:QName("VERSION_NOT_SUPPORTED"),
              fn:concat("MarkLogic ", xdmp:version(), " does not support external security. Use 7.0-0 or higher."))
          else
            xdmp:rethrow()
        }
      else
        $admin-config

  let $module-locations := $server-config/gr:module-locations
  let $admin-config :=
    if ($module-locations/*) then
      if (setup:at-least-version("7.0-0")) then
        xdmp:eval('
          xquery version "1.0-ml";

          import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

          declare namespace gr="http://marklogic.com/xdmp/group";

          declare variable $admin-config external;
          declare variable $server-id external;
          declare variable $module-locations external;

          let $old-module-locations := admin:appserver-get-module-locations($admin-config, $server-id)
          let $config :=
            (: First delete any module-location that matches the namespace :)
            admin:appserver-delete-module-location(
              $admin-config,
              $server-id,
              for $module-location in $module-locations/*
              return
                $old-module-locations[gr:namespace-uri = $module-location/gr:namespace-uri][gr:location ne $module-location/gr:location])
          return
            (: Then add in any module-location whose namespace isnt already defined :)
            admin:appserver-add-module-location(
              $config,
              $server-id,
              for $module-location in $module-locations/*
              return
                if ($old-module-locations[gr:namespace-uri = $module-location/gr:namespace-uri][gr:location = $module-location/gr:location]) then ()
                else
                  $module-location)
          ',
          (xs:QName("admin-config"),$admin-config,
           xs:QName("server-id"),$server-id,
           xs:QName("module-locations"),$module-locations))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support module-locations. Use 7.0-0 or higher."))
    else
      $admin-config

  let $request-blackouts := $server-config/gr:request-blackouts/gr:request-blackout
  let $admin-config :=
    if ($request-blackouts) then
      let $old-request-blackouts := admin:appserver-get-request-blackouts($admin-config, $server-id)
      let $config :=
        (: First delete any request-blackout that matches type and period :)
        admin:appserver-delete-request-blackout(
          $admin-config,
          $server-id,
          for $request-blackout in $request-blackouts
          return
            $old-request-blackouts[setup:get-request-blackout-hash(.) = setup:get-request-blackout-hash($request-blackout)][gr:users ne $request-blackout/gr:users or gr:roles ne $request-blackout/gr:roles])
      return
        (: Then add in any request-blackout whose type and period aren't already defined :)
        admin:appserver-add-request-blackout(
          $config,
          $server-id,
          for $request-blackout in $request-blackouts
          return
            if ($old-request-blackouts[setup:get-request-blackout-hash(.) = setup:get-request-blackout-hash($request-blackout)][gr:users eq $request-blackout/gr:users and gr:roles eq $request-blackout/gr:roles]) then ()
            else
              $request-blackout)
    else
      $admin-config

  return
    $admin-config
};

declare function setup:get-request-blackout-hash($blackout) {
  string-join(($blackout/gr:blackout-type, $blackout//gr:day, $blackout//start-date, $blackout//start-time, $blackout//end-date, $blackout//end-time), '-')
};

declare function setup:validate-server(
  $server-config as element(),
  $server-id as xs:unsignedLong,
  $settings as element(settings)) as item()*
{
  let $admin-config := admin:get-configuration()
  return (

    for $setting in $settings/*:setting
    let $setting-test :=
      if ($setting/@accept-blank = "true") then
        ""
      else
        "[fn:string-length(fn:string(.)) > 0]"
    let $expected :=
      if ($setting/@value) then
        xdmp:value($setting/@value)
      else
        fn:data(xdmp:value(fn:concat("$server-config/gr:", $setting, $setting-test)))
    let $min-version as xs:string? := $setting/@min-version
    where (fn:exists($expected))
    return
      if (fn:empty($min-version) or setup:at-least-version($min-version)) then
        let $actual := xdmp:value(fn:concat("admin:appserver-get-", $setting, "($admin-config, $server-id)"))
        return
          if ($expected = $actual) then ()
          else
            setup:validation-fail(fn:concat("Appserver ", $setting, " mismatch: ", $expected, " != ", $actual))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support ", $setting, ". Use ", $min-version, " or higher.")),

    let $existing := admin:appserver-get-namespaces($admin-config, $server-id)
    for $expected in $server-config/gr:namespaces/gr:namespace
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Appserver missing namespace: ", $expected/gr:namespace-uri)),

    let $existing := admin:appserver-get-schemas($admin-config, $server-id)
    for $expected in $server-config/gr:schemas/gr:schema
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Appserver missing schema: ", $expected/gr:schema)),

    if ($server-config/gr:module-locations/gr:module-location) then
      if (setup:at-least-version("7.0-0")) then
        let $existing :=
          xdmp:eval('
            xquery version "1.0-ml";

            import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

            declare variable $admin-config external;
            declare variable $server-id external;

            admin:appserver-get-module-locations($admin-config, $server-id)
            ',
            (xs:QName("admin-config"),$admin-config,
             xs:QName("server-id"),$server-id))
        for $expected in $server-config/gr:module-locations/gr:module-location
        return
          if ($existing[fn:deep-equal(., $expected)]) then ()
          else
            setup:validation-fail(fn:concat("Appserver missing module location: ", $expected/gr:module-location))
      else
        fn:error(
          xs:QName("VERSION_NOT_SUPPORTED"),
          fn:concat("MarkLogic ", xdmp:version(), " does not support module-locations. Use 7.0-0 or higher."))
    else (),

    let $existing := admin:appserver-get-request-blackouts($admin-config, $server-id)
    for $expected in $server-config/gr:request-blackouts/gr:request-blackout
    return
      if ($existing[fn:deep-equal(., $expected)]) then ()
      else
        setup:validation-fail(fn:concat("Appserver missing request blackout: ", $expected/gr:request-blackout))
  )
};

declare function setup:create-scheduled-tasks(
  $import-config as element(configuration))
{
  for $task-server in $import-config/gr:groups/gr:group/gr:task-server
  let $group-id := setup:get-group($task-server)
  let $tasks :=
    for $task in $task-server/gr:scheduled-tasks/gr:scheduled-task
    let $existing := setup:get-scheduled-task($task, $group-id)
    where fn:not(fn:exists($existing))
    return
      setup:create-scheduled-task($task)
  let $admin-config := admin:get-configuration()
  let $admin-config :=
    if ($tasks) then
      admin:group-add-scheduled-task(
        $admin-config,
        $group-id,
        $tasks)
    else
      $admin-config
  return
  (
    if (admin:save-configuration-without-restart($admin-config)) then
      xdmp:set($restart-needed, fn:true())
    else (),
    if ($tasks) then
      setup:add-rollback("task-server", $task-server)
    else (),
    fn:concat("Scheduled tasks created succesfully.")
  )
};

declare function setup:create-scheduled-task(
  $task as element(gr:scheduled-task))
{
  let $admin-config := admin:get-configuration()
  return
    if ($task/gr:task-type eq "daily") then
      admin:group-daily-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-period,
        $task/gr:task-start-time,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else if ($task/gr:task-type eq "hourly") then
      admin:group-hourly-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-period,
        $task/gr:task-minute,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else if ($task/gr:task-type eq "minutely") then
      admin:group-minutely-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-period,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else if ($task/gr:task-type eq "monthly") then
      admin:group-monthly-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-period,
        $task/gr:task-month-day,
        $task/gr:task-start-time,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else if ($task/gr:task-type eq "once") then
      admin:group-one-time-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-start,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else if ($task/gr:task-type eq "weekly") then
      admin:group-weekly-scheduled-task(
        $task/gr:task-path,
        $task/gr:task-root,
        $task/gr:task-period,
        $task/gr:task-days/gr:task-day,
        $task/gr:task-start-time,
        admin:database-get-id($admin-config, $task/gr:task-database/@name),
        admin:database-get-id($admin-config, $task/gr:task-modules/@name),
        setup:get-user-id($task/gr:task-user/@name),
        $task/gr:task-host/xdmp:host(.),
        $task/gr:task-priority)
    else ()
};

declare function setup:validate-scheduled-tasks(
  $import-config as element(configuration))
{
  for $task-server in $import-config/gr:groups/gr:group/gr:task-server
  let $group-id := setup:get-group($task-server)
  for $task in $task-server/gr:scheduled-tasks/gr:scheduled-task
  return
    setup:validate-scheduled-task($task, $group-id)
};

declare function setup:validate-scheduled-task(
  $task as element(gr:scheduled-task),
  $group-id as xs:unsignedLong)
{
  if (fn:not(fn:empty(setup:get-scheduled-task($task, $group-id)))) then ()
  else
    setup:validation-fail(fn:concat("Validation fail for ", xdmp:describe($task)))
};

declare function setup:get-scheduled-task(
  $task as element(gr:scheduled-task),
  $group-id as xs:unsignedLong) as element(gr:scheduled-task)?
{
  let $admin-config := admin:get-configuration()
  let $tasks :=
    admin:group-get-scheduled-tasks(
      $admin-config,
      $group-id)
  return
    $tasks[gr:task-path = $task/gr:task-path and
           gr:task-root = $task/gr:task-root and
           gr:task-type = $task/gr:task-type and
           gr:task-database = admin:database-get-id($admin-config, $task/gr:task-database/@name) and
           gr:task-modules = admin:database-get-id($admin-config, $task/gr:task-modules/@name) and
           gr:task-user = xdmp:user($task/gr:task-user/@name)]
          [if ($task/gr:task-period) then gr:task-period = $task/gr:task-period else fn:true()]
           (:[if ($task/gr:task-period) then gr:task-period = $task/gr:task-period else fn:true()]:)
(:           [if ($task/gr:task-start-time) then gr:task-start-time = $task/gr:task-start-time else fn:true()]
           [if ($task/gr:task-minute) then gr:task-minute = $task/gr:task-minute else fn:true()]
           [if ($task/gr:task-month-day) then gr:task-month-day = $task/gr:task-month-day else fn:true()]
           [if ($task/gr:task-days/gr:task-day) then fn:not(gr:task-days/gr:task-day != $task/gr:task-days/gr:task-day) else fn:true()]
           [if ($task/gr:task-host) then gr:task-host = $task/gr:task-host/xdmp:host(.) else fn:true()]
           [if ($task/gr:task-priority) then gr:task-priority = $task/gr:task-priority else fn:true()]:)
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
      else () (: noop :)
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
      else () (: noop :)
    else
      setup:validation-fail(fn:concat("Missing privilege: ", $privilege-name))
};

declare function setup:create-external-security(
  $import-config as element(configuration))
{
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>
  for $es in $import-config/sec:external-securities/sec:external-security
  return
    (: if it exists, don't recreate it :)
    if (setup:get-external-securities($es/sec:external-security-name)/sec:external-security) then ()
    else
    (
      (: Wrapping this in xdmp:eval because it didn't exist until ML7 :)
      try {
        xdmp:eval(
          'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
           declare variable $es as element(sec:external-security) external;

           sec:create-external-security(
             $es/sec:external-security-name,
             $es/sec:description,
             $es/sec:authentication,
             $es/sec:cache-timeout,
             $es/sec:authorization,
             $es/sec:ldap-server-uri,
             $es/sec:ldap-base,
             $es/sec:ldap-attribute,
             $es/sec:ldap-default-user,
             $es/sec:ldap-password)',
          (xs:QName("es"), $es),
          $eval-options)
      }
      catch($ex) {
        if ($ex/error:code = "XDMP-UNDFUN" and fn:not(setup:at-least-version("7.0-0"))) then
          fn:error(
              xs:QName("VERSION_NOT_SUPPORTED"),
              fn:concat("MarkLogic ", xdmp:version(), " does not support external security. Use 7.0-0 or higher."))
        else
          xdmp:rethrow()
      },
      setup:add-rollback("external-security", $es)
    )
};

declare function setup:validate-external-security(
  $import-config as element(configuration))
{
  for $es in $import-config/sec:external-securities/sec:external-security
  let $es-name as xs:string? := $es/sec:external-security-name
  let $match := setup:get-external-securities($es-name)
  return
    if ($match) then
      let $match-elements := $match/*[fn:not(fn:local-name(.) = 'external-security-id')]
      let $all-match :=
          for $e in $match-elements
          let $name := fn:node-name($e)
          return
            $es/*[fn:node-name(.) = $name] = $e
      let $has-mismatch := $all-match = fn:false()
      let $c1 := fn:count($es/*)
      let $c2 := fn:count($match-elements)
      return
      if ($c1 ne $c2 or $has-mismatch) then
        setup:validation-fail(fn:concat("Mismatched external-security ", $es-name))
      else ()
    else
      setup:validation-fail(fn:concat("Missing external-security ", $es-name))
};

declare function setup:create-roles(
  $import-config as element(configuration))
{
  for $role in $import-config/sec:roles/sec:role
  let $role-name as xs:string := $role/sec:role-name
  let $description as xs:string? := $role/sec:description
  let $collections as xs:string* := $role/sec:collections/sec:collection/fn:string()
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>
  return
    (: if the role exists, then don't create it :)
    if (setup:get-roles(())/sec:role[sec:role-name = $role-name]) then ()
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
    ),

  for $role in $import-config/sec:roles/sec:role
  let $role-name as xs:string := $role/sec:role-name
  let $description as xs:string? := $role/sec:description
  let $role-names as xs:string* := $role/sec:role-names/sec:role-name
  let $permissions as element(sec:permission)* := $role/sec:permissions/*
  let $collections as xs:string* := $role/sec:collections/sec:collection/fn:string()
  let $privileges as element(sec:privilege)* := $role/sec:privileges/sec:privilege
  let $amps as element(sec:amp)* := $role/sec:amps/*
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
    </options>
  return
  (
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       declare variable $role-name as xs:string external;
       declare variable $description as xs:string external;
       sec:role-set-description($role-name, $description)',
      (xs:QName("role-name"), $role-name,
       xs:QName("description"), fn:string($description)),
      $eval-options),

      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $role-name as xs:string external;
         declare variable $role-names as element() external;
         sec:role-set-roles($role-name, $role-names/*)',
        (xs:QName("role-name"), $role-name,
         xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
    $eval-options),

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
              xdmp:eval('
                declare variable $p external;

                xdmp:permission($p/sec:role-name, $p/sec:capability)',
                (xs:QName("p"), $p))
          }
          </w>
        ),
    $eval-options),

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

    (: remove the privileges before adding them back :)
    xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $role-name as xs:string external;
         sec:remove-role-from-privileges($role-name)',
         (xs:QName("role-name"), $role-name),
         $eval-options),

    (: add them back :)
    for $privilege in $privileges
    let $priv := setup:get-privilege-by-name($privilege/sec:privilege-name)
    let $validate-privilege :=
      if ($priv) then ()
      else
        fn:error(
          xs:QName("INVALID-PRIVILEGE"),
          fn:concat(
            "Invalid privilege '",
            $privilege/sec:privilege-name,
            "' specified for role: ",
            $role-name))
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
};

declare function setup:validate-roles(
  $import-config as element(configuration))
{
  for $role in $import-config/sec:roles/sec:role
  let $role-name as xs:string := $role/sec:role-name
  let $description as xs:string? := $role/sec:description
  let $role-names as xs:string* := $role/sec:role-names/sec:role-name
  let $permissions as element(sec:permission)* := $role/sec:permissions/sec:permission
  let $collections as xs:string* := $role/sec:collections/*
  let $privileges as element(sec:privilege)* := $role/sec:privileges/sec:privilege
  let $amps as element(sec:amp)* := $role/sec:amps/*
  let $match := setup:get-roles(())/sec:role[sec:role-name = $role-name]
  return
    if ($match) then
      if ($match/sec:role-name != $role-name or
          $match/sec:description != $description or
          $match/sec:role-names/sec:role-name != $role-names or
          fn:count($match/sec:permissions/sec:permission) != fn:count($permissions) or
          fn:count($match/sec:privileges/sec:privilege) != fn:count($privileges)) then
        setup:validation-fail(fn:concat("Mismatched role: ", $role-name))
      else ()
    else
      setup:validation-fail(fn:concat("Missing role: ", $role-name))
};

declare function setup:create-users($import-config as element(configuration))
{
  for $user in $import-config/sec:users/sec:user
  let $user-name as xs:string := $user/sec:user-name
  let $description as xs:string? := $user/sec:description
  let $password as xs:string := $user/sec:password
  let $role-names as xs:string* := $user/sec:role-names/*
  let $permissions as element(sec:permission)* := $user/sec:permissions/*
  let $collections as xs:string* := $user/sec:collections/*
  let $eval-options :=
    <options xmlns="xdmp:eval">
      <database>{$default-security}</database>
      <isolation>different-transaction</isolation>
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
  for $user in $import-config/sec:users/sec:user
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

declare function setup:create-amps($import-config)
{
  let $existing-amps := setup:get-amps(())
  for $amp in $import-config/sec:amps/sec:amp
  return
    if ($existing-amps/sec:amp[sec:namespace = $amp/sec:namespace and
                                   sec:local-name = $amp/sec:local-name and
                                   sec:document-uri = $amp/(sec:doc-uri, sec:document-uri) and
                                   sec:db-name = $amp/sec:db-name]) then ()
    else
    (
      xdmp:eval(
        'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
         declare variable $amp external;
         declare variable $db := if($amp/sec:db-name = "filesystem") then 0 else xdmp:database($amp/sec:db-name);
         sec:create-amp(
           $amp/sec:namespace,
           $amp/sec:local-name,
           $amp/(sec:doc-uri, sec:document-uri)[1],
           $db,
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
                                   sec:document-uri = $amp/(sec:doc-uri, sec:document-uri) and
                                   sec:db-name = $amp/sec:db-name]) then ()
    else
      setup:validation-fail(fn:concat("Missing amp: ", $amp/sec:local-name))
};

declare function setup:get-configuration(
  $databases as xs:string*,
  $forests as xs:string*,
  $app-servers as xs:string*,
  $users as xs:anySimpleType*,
  $roles as xs:anySimpleType*,
  $mimetypes as xs:string*) as element()
{
  let $user-configuration :=
      typeswitch($users[1])
        case xs:integer
          return setup:get-users($users)
        case xs:string
          return setup:get-users-by-name($users)
        default return setup:get-users(())
  let $role-configuration :=
      typeswitch($roles[1])
        case xs:integer
          return setup:get-roles($roles)
        case xs:string
          return setup:get-roles-by-name($roles)
        default return setup:get-roles(())
  return
    <configuration>
      {setup:get-app-servers($app-servers)}
      {setup:get-forests($forests)}
      {setup:get-databases($databases)}
      {$user-configuration}
      {$role-configuration}
      {setup:get-mimetypes($mimetypes)}
    </configuration>
};

declare function setup:get-app-servers($names as xs:string*) as element()*
{
  for $group in setup:read-config-file("groups.xml")/gr:groups/gr:group
  let $group-id as xs:unsignedLong := $group/gr:group-id
  let $group-name as xs:string := $group/gr:group-name
  return (
    let $http-servers := $group/gr:http-servers/gr:http-server[empty($names) or gr:http-server-name = $names]
    where $http-servers
    return
      <http-servers xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://marklogic.com/xdmp/group">
        {
          for $http-server in $http-servers
          return
            <http-server group="{$group-name}">
            {
              setup:resolve-ids-to-names(
                setup:strip-default-properties-from-http-server(
                  $http-server, $group-id
                )
              )
            }/(@*, node())
            </http-server>
        }
      </http-servers>,

    let $xdbc-servers := $group/gr:xdbc-servers/gr:xdbc-server[empty($names) or gr:xdbc-server-name = $names]
    where $xdbc-servers
    return
      <xdbc-servers xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://marklogic.com/xdmp/group">
        {
          for $xdbc-server in $xdbc-servers
          return
            <xdbc-server group="{$group-name}">
            {
              setup:resolve-ids-to-names(
                setup:strip-default-properties-from-xdbc-server(
                  $xdbc-server, $group-id
                )
              )/(@*, node())
            }
            </xdbc-server>
        }
      </xdbc-servers>,

    let $odbc-servers := $group/gr:odbc-servers/gr:odbc-server[empty($names) or gr:odbc-server-name = $names]
    where $odbc-servers
    return
      <odbc-servers xsi:schemaLocation="http://marklogic.com/xdmp/group group.xsd"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://marklogic.com/xdmp/group">
        {
          for $odbc-server in $odbc-servers
          return
            <odb-server group="{$group-name}">
            {
              setup:resolve-ids-to-names(
                setup:strip-default-properties-from-odbc-server(
                  $odbc-server, $group-id
                )
              )/(@*, node())
            }
            </odb-server>
        }
      </odbc-servers>
  )
};

declare function setup:get-forests($names as xs:string*) as element(as:assignments) {
  let $forests :=setup:read-config-file("assignments.xml")/as:assignments
  let $forests := $forests/as:assignment[empty($names) or as:forest-name = $names]
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
  let $databases := $databases/db:database[empty($names) or db:database-name = $names]
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

declare function setup:get-appserver-modules-database($server-config as element()) as xs:unsignedLong
{
  let $modules as xs:string? := $server-config/gr:modules/(@name|text())
  return
    if ($modules = ("filesystem", "0")) then 0
    else if ($modules) then xdmp:database($modules)
    else 0
};

declare function setup:get-appserver-content-database($server-config as element()) as xs:unsignedLong
{
  let $database as xs:string? := fn:data($server-config/gr:database/(@name|text()))
  return
    if ($database) then xdmp:database($database)
    else 0
};

declare function setup:get-last-login($server-config as element()) as xs:unsignedLong
{
  let $last-login as xs:string? := $server-config/gr:last-login/(@name|text())
  return
    if ($last-login = ("filesystem", "0")) then 0
    else if ($last-login) then xdmp:database($last-login)
    else 0
};

declare function setup:get-triggers-database($db-config as element(db:database)) as xs:unsignedLong
{
  let $db-name := fn:data($db-config/db:triggers-database/(@name|text()))
  return
    if ($db-name) then xdmp:database($db-name)
    else 0
};

declare function setup:get-schema-database($db-config as element(db:database)) as xs:unsignedLong
{
  let $db-name := fn:data($db-config/db:schema-database/(@name|text()))
  return
    if ($db-name) then xdmp:database($db-name)
    else $default-schemas
};

declare function setup:get-security-database($db-config as element(db:database)) as xs:unsignedLong
{
  let $db-name := fn:data($db-config/db:security-database/(@name|text()))
  return
    if ($db-name) then xdmp:database($db-name)
    else $default-security
};

declare function setup:get-appserver-default-user($server-config as element()) as xs:unsignedLong
{
  let $user as xs:string? := fn:data($server-config/gr:default-user/(@name|text()))
  return
    if ($user) then
      xdmp:eval('
        declare variable $username external;
        xdmp:user($username)',
        (xs:QName("username"), $user)
      )
    else $default-user
};

declare function setup:get-appserver-internal-security($server-config as element()) as xs:boolean?
{
  if (setup:at-least-version("7.0-0")) then
    (
      fn:data($server-config/gr:internal-security),
      fn:not(setup:get-appserver-external-security($server-config)[fn:not(. = "")]),
      fn:true()
    )[1]
  else ()
};

declare function setup:get-appserver-external-security($server-config as element()) as xs:string?
{
  fn:data($server-config/gr:external-security/(@name|text()))
};

declare function setup:get-ssl-certificate-template(
  $server-config as element())
as xs:unsignedLong
{
  let $v as xs:string? := $server-config/gr:ssl-certificate-template/(@name|text())
  return (
    if (not($v)) then 0
    else pki:template-get-id(pki:get-template-by-name($v))
  )
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

declare function setup:get-users-by-name($names as xs:string*) as element(sec:users)? {
  let $ids :=
    for $name in $names
      return setup:get-users-by-name-helper($name)
   return setup:get-users($ids)
};

declare function setup:get-users-by-name-helper($name as xs:string*) as xs:integer? {
  try{
    xdmp:user($name)
  } catch($e) {
  }
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

declare function setup:get-user-id($user-name as xs:string) as xs:unsignedLong? {
  xdmp:eval(
    'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
     declare variable $user-name as xs:string external;
     /sec:user[sec:user-name = $user-name]/sec:user-id',
     (xs:QName("user-name"), $user-name),
     <options xmlns="xdmp:eval">
       <database>{$default-security}</database>
     </options>)
};

declare function setup:get-roles-by-name($roles as xs:string*) as element(sec:roles)? {
  let $ids :=
    for $role in $roles
      return setup:get-roles-by-name-helper($role)
  return setup:get-roles($ids)
};

declare function setup:get-roles-by-name-helper($role as xs:string*) as xs:integer? {
  try{
    xdmp:role($role)
  } catch($e) {
  }
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

declare function setup:get-external-securities($names as xs:string*) as element(sec:external-securities)*
{
  let $external-securities :=
    xdmp:eval(
      'import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
       fn:collection(sec:security-collection())/sec:external-security
       ',
      (),
      <options xmlns="xdmp:eval">
        <database>{$default-security}</database>
      </options>)
  return
    element sec:external-securities {
      if ($names) then
        $external-securities[sec:external-security-name = $names]
      else
        $external-securities
    }
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
              try {
                xdmp:database-name($amp/sec:database)
              } catch ($e) {
                xdmp:log(("Roxy WARN: Orphaned amp detected", $amp)),
                "(missing)"
              }
          }
        }
    }</amps>
};

declare function setup:get-mimetypes($names as xs:string*) as element(mt:mimetypes)?
{
  let $mimes := setup:read-config-file("mimetypes.xml")/mt:mimetypes
  let $mimes := $mimes/mt:mimetype[empty($names) or mt:name = $names]
  where $mimes
  return
    <mimetypes xsi:schemaLocation="http://marklogic.com/xdmp/mimetypes mimetypes.xsd"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xmlns="http://marklogic.com/xdmp/mimetypes">
      {setup:resolve-ids-to-names($mimes)}
    </mimetypes>
};

declare function setup:resolve-database-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      xdmp:database-name(fn:data($node))
    }
  else ()
};

declare function setup:resolve-forest-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      xdmp:forest-name(fn:data($node))
    }
  else ()
};

declare function setup:resolve-host-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      xdmp:host-name(fn:data($node))
    }
  else ()
};

declare function setup:resolve-user-id-to-name($node as element()) as element()?
{
  if (fn:data($node) ne 0) then
    element {fn:node-name($node)}
    {
      setup:user-name(fn:data($node))
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

declare function setup:strip-default-properties-from-http-server(
  $node as element(gr:http-server),
  $group as xs:unsignedLong) as element(gr:http-server)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:http-server-create(
        admin:get-configuration(),
        $group,
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
  $node as element(gr:xdbc-server),
  $group as xs:unsignedLong) as element(gr:xdbc-server)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    let $default-properties :=
      admin:xdbc-server-create(
        admin:get-configuration(),
        $group,
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

declare function setup:strip-default-properties-from-odbc-server(
  $node as element(gr:odbc-server),
  $group as xs:unsignedLong) as element(gr:odbc-server)
{
  element { fn:node-name($node) }
  {
    $node/@*,

    (: Wrapping this in xdmp:eval because it didn't exist until ML6 :)
    let $default-properties :=
      try
      {
        xdmp:eval('
          xquery version "1.0-ml";
          import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
          declare namespace gr="http://marklogic.com/xdmp/group";
          declare variable $group external;
          declare variable $default-modules external;
          declare variable $default-database external;
          admin:odbc-server-create(
            admin:get-configuration(),
            $group,
            "default",
            "/",
            19999,
            $default-modules,
            $default-database)//gr:odbc-servers/gr:odbc-server[gr:odbc-server-name eq "default"]/*
          ',
          (xs:QName("group"), $group,
           xs:QName("default-modules"), $default-modules,
           xs:QName("default-database"), $default-database))
      }
      catch($ex)
      {
        if ($ex/error:code = "XDMP-UNDFUN" and fn:not(setup:at-least-version("6.0-2"))) then
          (: If we're not using a recent enough version of ML, then the properties are irrelevant. :)
          ()
        else
          xdmp:rethrow()
      }
    for $property in $node/*
    where fn:not($default-properties[fn:deep-equal(., $property)]) and
          fn:not($property/self::gr:odbc-server-id)
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

declare function setup:get-databases-from-config(
  $import-config as element(configuration)) as element(db:database)*
{
  for $db in $import-config/db:databases/db:database
  return
    if (fn:exists($db/@import)) then
      let $imported-db := $import-config/db:databases/db:database[db:database-name eq $db/@import]
      return
        element db:database
        {
          $db/@*[fn:not(fn:local-name(.) = "import")],
          $imported-db/@*[fn:not(fn:local-name(.) = $db/@*/fn:local-name(.))],
          $db/*,
          let $ignore := $db/*/fn:node-name(.)
          return
            $imported-db/*[fn:not(fn:node-name(.) = $ignore)]
        }
    else
      $db
};

declare function setup:get-database-name-from-database-config(
  $db-config as element(db:database)) as xs:string?
{
  $db-config/db:database-name[fn:string-length(fn:string(.)) > 0]
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

declare function setup:at-least-version($target)
{
  let $current := xdmp:version()
  let $current-formatted :=
    fn:concat(
      fn:format-number(xs:int(fn:replace($current, "^(\d+)\..*", "$1")), "000"), (: major :)
      fn:format-number(xs:int(fn:replace($current, "^\d+\.(\d+).*", "$1")), "000"), (: minor :)
      fn:format-number(xs:int(fn:replace($current, "^\d+\.\d+\-(\d+).*", "$1")), "000"), (: x.x-X :)
      if (fn:matches($current, "^\d+\.\d+\-\d+\.\d+")) then
        fn:format-number(xs:int(fn:replace($current, "^\d+\.\d+\-\d+\.(\d+)", "$1")), "000") (: x.x-x.X :)
      else "000"
    )
  let $target-formatted :=
    fn:concat(
      fn:format-number(xs:int(fn:replace($target, "^(\d+)\..*", "$1")), "000"), (: major :)
      fn:format-number(xs:int(fn:replace($target, "^\d+\.(\d+).*", "$1")), "000"), (: minor :)
      fn:format-number(xs:int(fn:replace($target, "^\d+\.\d+\-(\d+).*", "$1")), "000"), (: x.x-X :)
      if (fn:matches($target, "^\d+\.\d+\-\d+\.\d+")) then
        fn:format-number(xs:int(fn:replace($target, "^\d+\.\d+\-\d+\.(\d+)", "$1")), "000") (: x.x-x.X :)
      else "000"
    )
  return fn:compare($current-formatted, $target-formatted) >= 0
};


declare function setup:read-config-file($filename as xs:string) as document-node()
{
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/admin-module-read", "execute"),
  xdmp:read-cluster-config-file($filename)
};

declare function setup:user-name($user-id as xs:unsignedLong?) as xs:string
{
  let $user-id :=
    if ($user-id) then $user-id
    else fn:data(xdmp:get-request-user())
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

declare function setup:validation-fail($message)
{
  xdmp:log($message),
  fn:error(xs:QName("VALIDATION-FAIL"), $message)
};

declare function setup:validate-install($import-config as element(configuration))
{
  try
  {
    let $import-config := setup:rewrite-config($import-config)
    return (
      setup:validate-external-security($import-config),
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
      setup:validate-hosts-settings($import-config),
      setup:validate-groups($import-config),
      setup:validate-groups-settings($import-config),
      setup:validate-appservers($import-config),
      setup:validate-appservers-settings($import-config),
      setup:validate-scheduled-tasks($import-config)
    )
  }
  catch($ex)
  {
    (:
    xdmp:set-response-code(500, 'Internal Server Error'),
    xdmp:set-response-content-type("text/plain"),
    $ex
    :)
    xdmp:log($ex),
    fn:concat($ex/err:format-string/text(), '&#10;See MarkLogic Server error log for more details.')
  }
};

declare function setup:create-ssl-certificate-templates($import-config as element(configuration))
{
  for $cert in $import-config/pki:certificates/pki:certificate[fn:exists(pki:name/text())]
  return
    if (fn:empty(pki:get-template-by-name($cert/pki:name))) then
      xdmp:eval(
        '
        import module namespace pki = "http://marklogic.com/xdmp/pki" at "/MarkLogic/pki.xqy";
        declare variable $cert external;
        pki:insert-template(
          pki:create-template(
            $cert/pki:name,
            "Self-signed certificate",
            "rsa",
            <pki:key-options xmlns="ssl:options">
              <key-length>2048</key-length>
            </pki:key-options>,
            <req xmlns="http://marklogic.com/xdmp/x509">
              <version>0</version>
              <subject>
                <countryName>{ $cert/pki:countryName/fn:string() }</countryName>
                <stateOrProvinceName>{ $cert/pki:stateOrProvinceName/fn:string() }</stateOrProvinceName>
                <localityName>{ $cert/pki:localityName/fn:string() }</localityName>
                <organizationName>{ $cert/pki:organizationName/fn:string() }</organizationName>
                <organizationalUnitName>{ $cert/pki:organizationalUnitName/fn:string() }</organizationalUnitName>
                <commonName>{ xdmp:hostname() }</commonName>
                <emailAddress>{ $cert/pki:emailAddress/fn:string() }</emailAddress>
              </subject>
              <v3ext>
                <basicConstraints critical="false">CA:TRUE</basicConstraints>
                <keyUsage critical="false">Certificate Sign, CRL Sign</keyUsage>
                <nsCertType critical="false">SSL Server</nsCertType>
              </v3ext>
            </req>))',
        (xs:QName("cert"), $cert),
        <options xmlns="xdmp:eval">
          <database>{xdmp:security-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    else ()

};

declare function setup:get-group($server-config as element()) as xs:unsignedLong
{
  (: app servers :)
  if ($server-config/ancestor::gr:group/gr:group-name) then
    xdmp:group($server-config/ancestor::gr:group/gr:group-name)
  (: databases :)
  else if ($server-config/@group) then
    xdmp:group($server-config/@group)
  (: revert to defaults :)
  else if ($server-config/ancestor::*:configuration/@default-group) then
    xdmp:group($server-config/ancestor::*:configuration/@default-group)
  else
    xdmp:group("Default")
};

declare function setup:get-host-group($host-config as element(ho:host)) as xs:unsignedLong
{
  if ($host-config/ho:group/@name) then
    xdmp:group($host-config/ho:group/@name)
  (: revert to defaults :)
  else if ($host-config/ancestor::*:configuration/@default-group) then
    xdmp:group($host-config/ancestor::*:configuration/@default-group)
  else
    xdmp:group("Default")
};

declare function setup:list-settings($type as xs:string) as item()*
{
  let $settings :=
    if ($type = "group") then
      $group-settings
    else if ($type = "host") then
      $host-settings
    else if ($type = "database") then
      $database-settings
    else if ($type = "http-server") then
      $http-server-settings
    else if ($type = "xdbc-server") then
      $xdbc-server-settings
    else if ($type = "odbc-server") then
      $odbc-server-settings
    else if ($type = "webdav-server") then
      $webdav-server-settings
    else if ($type = "task-server") then
      $task-server-settings
    else ()
  return
  if ($settings) then
    for $setting in $settings/*
    order by $setting
    return
      fn:concat(
        "- ",
        if ($setting/@min-version and fn:not(setup:at-least-version($setting/@min-version))) then
          "NOT SUPPORTED: "
        else (),
        fn:string($setting),
        if ($setting/@min-version) then
          fn:concat(" (>= v", $setting/@min-version, ")")
        else ()
      )
  else
    fn:concat("Unknown type of settings: ", $type)
};

(:
 : Force update mode. This is so that we can create an SSL certificate template
 : and then tell an app server to use it.
 :)
if ( 1 = 2 )
then ( xdmp:document-insert("fake.xml", <a/>) ) else (),

