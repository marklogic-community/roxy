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

(: A note on naming conventions:
  $admin-config refers to the configuration passed around by the Admin APIs
  $import-config is the import/export configuration format that setup:get-configuration() generates
:)

declare function setup:do-setup($import-config as element(configuration)) as item()*
{
    setup:create-privileges($import-config),
    setup:create-roles($import-config),
    setup:create-roles($import-config),
    setup:create-users($import-config),
    setup:create-mimetypes($import-config),
    setup:create-forests($import-config),
    setup:create-databases($import-config),
    setup:attach-forests($import-config),
    setup:apply-databases-settings($import-config),
    setup:configure-databases($import-config),
    setup:create-appservers($import-config),
    setup:apply-appservers-settings($import-config)
};

declare function setup:do-wipe($import-config as element(configuration)) as item()*
{
  let $config := admin:get-configuration()
  let $groupid := xdmp:group()
  return
  (
    for $x in ($import-config/gr:http-servers/gr:http-server/gr:http-server-name, $import-config/gr:xdbc-servers/gr:xdbc-server/gr:xdbc-server-name)
    return
      try{
        xdmp:set($config, admin:appserver-delete($config, admin:appserver-get-id($config, $groupid, $x)))
      } catch($ex){xdmp:log($ex)}
    ,
    admin:save-configuration-without-restart($config)
  ),

  let $config := admin:get-configuration()
  let $groupid := xdmp:group()
  return
  (
    for $x in $import-config/db:databases/db:database/db:database-name
    return
        try { xdmp:set($config, admin:database-delete($config, admin:database-get-id($config, $x))) } catch ($e) {xdmp:log($e)}
    ,
    admin:save-configuration-without-restart($config)
  ),

  let $config := admin:get-configuration()
  let $groupid := xdmp:group()
  return
  (
    for $x in $import-config/as:assignments/as:assignment/as:forest-name
    return
        try { xdmp:set($config, admin:forest-delete($config, admin:forest-get-id($config, $x), fn:true())) } catch ($e) {xdmp:log($e)}
    ,
    admin:save-configuration($config)
  ),

  let $config := admin:get-configuration()
  let $groupid := xdmp:group()
  return
  (
    for $x in $import-config/mt:mimetypes/mt:mimetype
    return
        try { xdmp:set($config, admin:mimetypes-delete($config, admin:mimetype($x/mt:name, $x/mt:extension, $x/mt:format))) } catch ($e) {xdmp:log($e)}
    ,
    admin:save-configuration($config)
  ),

  for $user in $import-config/sec:users/sec:user/sec:user-name
  return
    xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
               declare variable $user as xs:string external;
               try { sec:remove-user($user) } catch ($e) {xdmp:log($e)}',
               (xs:QName("user"), $user), <options xmlns="xdmp:eval"><database>{xdmp:database("Security")}</database></options>),


  for $role in $import-config/sec:roles/sec:role/sec:role-name
  return
    xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
               declare variable $role as xs:string external;
               try { sec:remove-role($role) } catch ($e) {xdmp:log($e)}',
               (xs:QName("role"), $role), <options xmlns="xdmp:eval"><database>{xdmp:database("Security")}</database></options>),

   for $priv in $import-config/sec:privileges/sec:privilege
   return
     xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                declare variable $action as xs:string external;
                declare variable $kind as xs:string external;
                try { sec:remove-privilege($action, $kind) } catch ($e) {xdmp:log($e)}',
                (xs:QName("action"), $priv/sec:action, xs:QName("kind"), $priv/sec:kind), <options xmlns="xdmp:eval"><database>{xdmp:database("Security")}</database></options>)

};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of mimetypes
 ::)

declare function setup:create-mimetypes($import-config as element(configuration)) as item()*
{
	try {
		for $mimetype-config in setup:get-mimetypes-from-config($import-config)
		return
			setup:create-mimetype($mimetype-config/mt:name, $mimetype-config/mt:extension, $mimetype-config/mt:format)
	} catch ($e) {
		fn:concat("Mimetype creation failed: ", $e//err:format-string)
	}
};

declare function setup:create-mimetype($name as xs:string, $extension as xs:string, $format as xs:string) as item()*
{
	try {
		let $admin-config := admin:get-configuration()
	  return

		if (admin:mimetypes-get($admin-config)[mt:name = $name]) then
			fn:concat("Mimetype ", $name, " already exists, not recreated..")
		else
			let $admin-config :=
				admin:mimetypes-add($admin-config, admin:mimetype($name, $extension, $format))
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)
			return
				fn:concat("Mimetype ", $name, " succesfully created", if ($restart-hosts) then " (note: restart required)" else ())
	} catch ($e) {
		fn:concat("Mimetype ", $name, " creation failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of forests
 ::)

declare function setup:create-forests($import-config as element(configuration)) as item()*
{
	try {
		for $forest-config in
			setup:get-forests-from-config($import-config)

		let $forest-name :=
			setup:get-forest-name-from-forest-config($forest-config)
		let $data-directory :=
			setup:get-data-directory-from-forest-config($forest-config)

		return
			setup:create-forest($forest-name, $data-directory)

	} catch ($e) {
		fn:concat("Forests creation failed: ", $e//err:format-string)
	}
};

declare function setup:create-forest($forest-name as xs:string, $data-directory as xs:string?) as item()*
{
	try {
		if (xdmp:forests()[$forest-name = xdmp:forest-name(.)]) then
			fn:concat("Forest ", $forest-name, " already exists, not recreated..")
		else
			let $admin-config :=
				admin:get-configuration()
			let $admin-config :=
				admin:forest-create($admin-config, $forest-name, $default-host, $data-directory)
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)

			return
				fn:concat("Forest ", $forest-name, " succesfully created", if ($data-directory) then fn:concat(" at ", $data-directory)
 else (), "..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Forest ", $forest-name, " creation failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of databases
 ::)

declare function setup:create-databases($import-config as element(configuration)) as item()*
{
	try {
		for $database-config in
			setup:get-databases-from-config($import-config)

		return
			setup:create-database($database-config)

	} catch ($e) {
		fn:concat("Databases creation failed: ", $e//err:format-string)
	}
};

declare function setup:create-database($database-config as element(db:database)) as item()*
{
	let $database-name :=
		setup:get-database-name-from-database-config($database-config)
	return

	try {
			if (xdmp:databases()[$database-name = xdmp:database-name(.)]) then
				fn:concat("Database ", $database-name, " already exists, not recreated..")
			else
				let $admin-config :=
					admin:get-configuration()
				let $admin-config :=
					admin:database-create($admin-config, $database-name, $default-security, $default-schemas)
				let $restart-hosts :=
					admin:save-configuration-without-restart($admin-config)

				return
					fn:concat("Database ", $database-name, " succesfully created..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Database ", $database-name, " creation failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Attaching forests to databases
 ::)

declare function setup:attach-forests($import-config as element(configuration)) as item()*
{
	try {
		for $database-config in
			setup:get-databases-from-config($import-config)

		return
			setup:attach-forests-to-database($database-config)

	} catch ($e) {
		fn:concat("Attaching forests failed: ", $e//err:format-string)
	}
};

declare function setup:attach-forests-to-database($database-config as element(db:database)) as item()*
{
	let $database-name :=
		setup:get-database-name-from-database-config($database-config)
	return

	try {
		for $forest-ref in
			setup:get-forest-refs-from-database-config($database-config)

		let $forest-name :=
			fn:data($forest-ref/@name)

		return
			setup:attach-database-forest($database-name, $forest-name)

	} catch ($e) {
		fn:concat("Attaching forests to database ", $database-name, " failed: ", $e//err:format-string)
	}
};

declare function setup:attach-database-forest($database-name as xs:string, $forest-name as xs:string) as item()*
{
	try {
		if (fn:not(xdmp:databases()[$database-name = xdmp:database-name(.)])) then
			fn:concat("Database ", $database-name, " does not exist, forest ", $forest-name, " not attached. Database creation might have failed..")
		else if (fn:not(xdmp:forests()[$forest-name = xdmp:forest-name(.)])) then
			fn:concat("Forest ", $forest-name, " does not exist, not attached to database ", $database-name, ". Forest creation might have failed or is missing in the import..")
		else if (xdmp:database-forests(xdmp:database($database-name))[$forest-name = xdmp:forest-name(.)]) then
			let $admin-config :=
				admin:get-configuration()
			let $admin-config :=
				admin:database-detach-forest($admin-config, xdmp:database($database-name), xdmp:forest($forest-name))
			let $admin-config :=
				admin:database-attach-forest($admin-config, xdmp:database($database-name), xdmp:forest($forest-name))
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)
			return
				fn:concat("Forest ", $forest-name, " succesfully reattached to database ", $database-name, "..", if ($restart-hosts) then " (note: restart required)" else ())
		else
			let $admin-config :=
				admin:get-configuration()
			let $admin-config :=
				admin:database-attach-forest($admin-config, xdmp:database($database-name), xdmp:forest($forest-name))
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)
			return
				fn:concat("Forest ", $forest-name, " succesfully attached to database ", $database-name, "..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Attaching forest ", $forest-name, " to database ", $database-name, " failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Applying of database settings
 ::)

declare function setup:apply-databases-settings($import-config as element(configuration)) as item()*
{
	try {
		for $database-config in
			setup:get-databases-from-config($import-config)

		return
			setup:apply-database-settings($database-config)

	} catch ($e) {
		fn:concat("Applying database settings failed: ", $e//err:format-string)
	}
};

declare function setup:apply-database-settings($database-config as element(db:database)) as item()*
{
	let $database-name :=
		setup:get-database-name-from-database-config($database-config)

	return

	try {
		let $admin-config := admin:get-configuration()
		let $database := xdmp:database($database-name)

		let $value := setup:get-setting-from-database-config-as-string($database-config, "language")
		let $admin-config :=
			if ($value) then
				admin:database-set-language($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "stemmed-searches")
		let $admin-config :=
			if ($value) then
				admin:database-set-stemmed-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "word-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-word-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "word-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-word-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-phrase-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-phrase-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-reverse-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-reverse-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-case-sensitive-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-case-sensitive-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-diacritic-sensitive-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-diacritic-sensitive-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-element-word-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-element-word-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "element-word-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-element-word-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-element-phrase-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-element-phrase-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "element-value-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-element-value-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "attribute-value-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-attribute-value-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "three-character-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-three-character-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "three-character-word-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-three-character-word-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-element-character-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-element-character-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "trailing-wildcard-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-trailing-wildcard-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "trailing-wildcard-word-positions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-trailing-wildcard-word-positions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "fast-element-trailing-wildcard-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-fast-element-trailing-wildcard-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "two-character-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-two-character-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "one-character-searches")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-one-character-searches($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "uri-lexicon")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-uri-lexicon($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "collection-lexicon")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-collection-lexicon($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "reindexer-enable")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-reindexer-enable($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "reindexer-throttle")
		let $admin-config :=
			if ($value) then
				admin:database-set-reindexer-throttle($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "reindexer-timestamp")
		let $admin-config :=
			if ($value) then
				admin:database-set-reindexer-timestamp($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "directory-creation")
		let $admin-config :=
			if ($value) then
				admin:database-set-directory-creation($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "maintain-last-modified")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-maintain-last-modified($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "maintain-directory-last-modified")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-maintain-directory-last-modified($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "inherit-permissions")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-inherit-permissions($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "inherit-collections")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-inherit-collections($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-boolean($database-config, "inherit-quality")
		let $admin-config :=
			if (fn:exists($value)) then
				admin:database-set-inherit-quality($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "format-compatibility")
		let $admin-config :=
			if ($value) then
				admin:database-set-format-compatibility($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "index-detection")
		let $admin-config :=
			if ($value) then
				admin:database-set-index-detection($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "expunge-locks")
		let $admin-config :=
			if ($value) then
				admin:database-set-expunge-locks($admin-config, $database, $value)
			else
				$admin-config

		let $value := setup:get-setting-from-database-config-as-string($database-config, "tf-normalization")
		let $admin-config :=
			if ($value) then
				admin:database-set-tf-normalization($admin-config, $database, $value)
			else
				$admin-config

		let $restart-hosts :=
			admin:save-configuration-without-restart($admin-config)
		return
			fn:concat("Database ", $database-name, " settings applied succesfully..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Applying settings to database ", $database-name, " failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Configuration of databases
 ::)

declare function setup:configure-databases($import-config as element(configuration)) as item()*
{
	try {
		for $database-config in
			setup:get-databases-from-config($import-config)

		return
			setup:configure-database($database-config)

	} catch ($e) {
		fn:concat("Configuring databases failed: ", $e//err:format-string)
	}
};

declare function setup:configure-database($database-config as element(db:database)) as item()*
{
	let $database-name :=
		setup:get-database-name-from-database-config($database-config)

	return

	try {
		let $admin-config :=
			admin:get-configuration()

		let $database :=
			xdmp:database($database-name)

		let $admin-config :=
			setup:add-word-lexicons($admin-config, $database, $database-config)

    let $admin-config :=
      setup:add-fragment-roots($admin-config, $database, $database-config)
		(:
		  <fragment-roots />
		  <fragment-parents />
		  <element-word-query-throughs />
		  <phrase-throughs />
		  <phrase-arounds />
		  <range-element-attribute-indexes />
		  <element-word-lexicons />
		  <element-attribute-word-lexicons />
		  <geospatial-element-indexes />
		  <geospatial-element-child-indexes />
		  <geospatial-element-pair-indexes />
		  <geospatial-element-attribute-pair-indexes />

		:)

		let $admin-config := setup:set-schema-database($admin-config, $database-config, $database)
		let $admin-config := setup:set-security-database($admin-config, $database-config, $database)
		let $admin-config := setup:set-triggers-database($admin-config, $database-config, $database)

		(: remove any existing range index (copied from default.xqy) :)
		let $remove-existing-indexes :=
			for $index in admin:database-get-range-element-indexes($admin-config, $database)
			return
				xdmp:set($admin-config, admin:database-delete-range-element-index($admin-config, $database, $index))

		let $admin-config := setup:add-range-element-indexes($admin-config, $database, $database-config)

    (: remove any existing range element attribute index :)
    let $remove-existing-indexes :=
      for $index in admin:database-get-range-element-attribute-indexes($admin-config, $database)
      return
        xdmp:set($admin-config, admin:database-delete-range-element-attribute-index($admin-config, $database, $index))

    let $admin-config := setup:add-range-element-attribute-indexes($admin-config, $database, $database-config)

    (: remove any existing geospatial element attribute pair indexes :)
    let $remove-existing-indexes :=
      for $index in admin:database-get-geospatial-element-attribute-pair-indexes($admin-config, $database)
      return
        xdmp:set($admin-config, admin:database-delete-geospatial-element-attribute-pair-index($admin-config, $database, $index))

    let $admin-config := setup:add-geospatial-element-attribute-pair-indexes($admin-config, $database, $database-config)

    (: remove any existing geospatial element  pair indexes :)
    let $remove-existing-indexes :=
      for $index in admin:database-get-geospatial-element-pair-indexes($admin-config, $database)
      return
        xdmp:set($admin-config, admin:database-delete-geospatial-element-pair-index($admin-config, $database, $index))

    let $admin-config := setup:add-geospatial-element-pair-indexes($admin-config, $database, $database-config)

		(: remove any existing field (copied from default.xqy) :)
		let $remove-existing-fields :=
			for $field as xs:string in admin:database-get-fields($admin-config, $database)/db:field-name
			return
				xdmp:set($admin-config, admin:database-delete-field($admin-config, $database, $field))

		let $admin-config := setup:add-fields($admin-config, $database, $database-config)

		let $restart-hosts :=
			admin:save-configuration-without-restart($admin-config)

		return
			fn:concat("Database ", $database-name, " configured succesfully..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Database ", $database-name, " configuration failed: ", $e//err:format-string)
	}
};

declare function setup:add-fields($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $fields := $database-config/db:fields/db:field
  let $field-configs :=
    ($fields,
     if ($fields[db:field-name = ""]) then ()
     else
      <field xmlns="http://marklogic.com/xdmp/database">
    	  <field-name/>
      	<include-root>true</include-root>
      	<included-elements/>
      	<excluded-elements/>
      </field>
      )
  return setup:add-fields-R($admin-config, $database, $field-configs)
};


declare function setup:add-fields-R($admin-config as element(configuration), $database as xs:unsignedLong, $field-configs as element(db:field)*) as element(configuration)
{
  if (fn:empty($field-configs)) then
    $admin-config
  else
    let $field-config := $field-configs[1]
    let $admin-config :=
      try { admin:database-add-field($admin-config, $database, $field-config) }
      catch ($e) { $admin-config }
    return setup:add-fields-R($admin-config, $database, fn:subsequence($field-configs, 2))
};


declare function setup:add-range-element-indexes($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $index-configs := $database-config/db:range-element-indexes/db:range-element-index
  return setup:add-range-element-indexes-R($admin-config, $database, $index-configs)
};

declare function setup:add-range-element-indexes-R($admin-config as element(configuration), $database as xs:unsignedLong, $index-configs as element(db:range-element-index)*) as element(configuration)
{
  if (fn:empty($index-configs)) then
    $admin-config
  else
    let $index-config := $index-configs[1]
    let $admin-config :=
      try { admin:database-add-range-element-index($admin-config, $database, $index-config) }
      catch ($e) { $admin-config }
    return setup:add-range-element-indexes-R($admin-config, $database, fn:subsequence($index-configs, 2))
};

declare function setup:add-range-element-attribute-indexes($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $index-configs := $database-config/db:range-element-attribute-indexes/db:range-element-attribute-index
  return setup:add-range-element-attribute-indexes-R($admin-config, $database, $index-configs)
};

declare function setup:add-range-element-attribute-indexes-R($admin-config as element(configuration), $database as xs:unsignedLong, $index-configs as element(db:range-element-attribute-index)*) as element(configuration)
{
  if (fn:empty($index-configs)) then
    $admin-config
  else
    let $index-config := $index-configs[1]
    let $admin-config :=
      try { admin:database-add-range-element-attribute-index($admin-config, $database, $index-config) }
      catch ($e) { $admin-config }
    return setup:add-range-element-attribute-indexes-R($admin-config, $database, fn:subsequence($index-configs, 2))
};

declare function setup:add-geospatial-element-attribute-pair-indexes($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $index-configs := $database-config/db:geospatial-element-attribute-pair-indexes/db:geospatial-element-attribute-pair-index
  return setup:add-geospatial-element-attribute-pair-indexes-R($admin-config, $database, $index-configs)
};

declare function setup:add-geospatial-element-attribute-pair-indexes-R($admin-config as element(configuration), $database as xs:unsignedLong, $index-configs as element(db:geospatial-element-attribute-pair-index)*) as element(configuration)
{
  if (fn:empty($index-configs)) then
    $admin-config
  else
    let $index-config := $index-configs[1]
    let $admin-config :=
      try { admin:database-add-geospatial-element-attribute-pair-index($admin-config, $database, $index-config) }
      catch ($e) { $admin-config }
    return setup:add-geospatial-element-attribute-pair-indexes-R($admin-config, $database, fn:subsequence($index-configs, 2))
};

declare function setup:add-geospatial-element-pair-indexes($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $index-configs := $database-config/db:geospatial-element-pair-indexes/db:geospatial-element-pair-index
  return setup:add-geospatial-element-pair-indexes-R($admin-config, $database, $index-configs)
};

declare function setup:add-geospatial-element-pair-indexes-R($admin-config as element(configuration), $database as xs:unsignedLong, $index-configs as element(db:geospatial-element-pair-index)*) as element(configuration)
{
  if (fn:empty($index-configs)) then
    $admin-config
  else
    let $index-config := $index-configs[1]
    let $admin-config :=
      try { admin:database-add-geospatial-element-pair-index($admin-config, $database, $index-config) }
      catch ($e) { $admin-config }
    return setup:add-geospatial-element-pair-indexes-R($admin-config, $database, fn:subsequence($index-configs, 2))
};

declare function setup:add-word-lexicons($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $collations := fn:string($database-config/db:word-lexicons/db:word-lexicon)
  return setup:add-word-lexicons-R($admin-config, $database, $collations)
};

declare function setup:add-word-lexicons-R($admin-config as element(configuration), $database as xs:unsignedLong, $collations as xs:string*) as element(configuration)
{
  if (fn:empty($collations)) then
    $admin-config
  else
    let $admin-config := setup:safe-database-add-word-lexicon($admin-config, $database, $collations[1])
    return setup:add-word-lexicons-R($admin-config, $database, fn:subsequence($collations, 2))
};


declare function setup:safe-database-add-word-lexicon($admin-config as element(configuration), $database as xs:unsignedLong, $collation as xs:string) as element(configuration)
{
  try {
	let $lexspec := admin:database-word-lexicon($collation)
	return admin:database-add-word-lexicon($admin-config, $database, $lexspec)
  } catch ($e) {$admin-config}
};

declare function setup:add-fragment-roots($admin-config as element(configuration), $database as xs:unsignedLong, $database-config as element(db:database)) as element(configuration)
{
  let $fragment-roots := $database-config/db:fragment-roots/db:fragment-root
  return setup:add-fragment-roots-R($admin-config, $database, $fragment-roots)

};

declare function setup:add-fragment-roots-R($admin-config as element(configuration), $database as xs:unsignedLong, $fragment-roots as element(db:fragment-root)*) as element(configuration)
{
  if (fn:empty($fragment-roots)) then
    $admin-config
  else
    let $fragment-root := $fragment-roots[1]
    let $admin-config :=
      try { admin:database-add-fragment-root($admin-config, $database, admin:database-fragment-root($fragment-root/db:namespace-uri, $fragment-root/db:localname)) }
      catch ($e) { $admin-config }
    return setup:add-fragment-roots-R($admin-config, $database, fn:subsequence($fragment-roots, 2))
};

declare function setup:safe-database-add-range-element-index($admin-config as element(configuration), $database-name, $rangespec) as element(configuration)
{
  try {
    admin:database-add-range-element-index($admin-config, xdmp:database($database-name), $rangespec)
  }
  catch ($e) {
    $admin-config
  }
};


(: $includes is a sequence of alternating namespaces and element names. Assumes no attributes and weights of 1.0 :)
declare function setup:safe-database-add-field($admin-config as element(configuration), $database-name, $field-name, $incl-root, $includes) as element(configuration)
{
  let $fieldspec := admin:database-field($field-name, $incl-root)
  let $admin-config :=
    try {admin:database-add-field($admin-config, xdmp:database($database-name), $fieldspec)}
    catch ($e) {$admin-config}

  return setup:safe-database-field-includes($admin-config, $database-name, $field-name, $includes)
};


declare function setup:safe-database-field-includes($admin-config as element(configuration), $database-name, $field-name, $includes) as element(configuration)
{
  if (fn:count($includes) = 0) then
    $admin-config
  else if (fn:count($includes) >= 2) then
    let $fieldspec := admin:database-included-element($includes[1], $includes[2], 1.0, "", "", "")
    let $admin-config :=
      try {admin:database-add-field-included-element($admin-config, xdmp:database($database-name), $field-name, $fieldspec)}
      catch ($e) {$admin-config}
    return (: recurse :)
      setup:safe-database-field-includes($admin-config, $database-name, $field-name, fn:subsequence($includes, 3))
  else
    fn:error(xs:QName("error"), "Odd number of field includes")
};

(:
  if the triggers database is 0, set it to 0.
  if the triggers database is set to an ID of another database in the import, get its new ID and set it to that
:)
declare function setup:set-triggers-database($admin-config as element(configuration), $database-config as element(db:database), $database as xs:unsignedLong) as element(configuration)
{
	let $triggers-database-id := if ($database-config/db:triggers-database/@name) then xdmp:database($database-config/db:triggers-database/@name) else 0
	return
		admin:database-set-triggers-database($admin-config, $database, $triggers-database-id)
};


(:
  if the schema database is 0, set it to 0.
  if the schema database is set to an ID of another database in the import, get its new ID and set it to that
:)
declare function setup:set-schema-database($admin-config as element(configuration), $database-config as element(db:database), $database as xs:unsignedLong) as element(configuration)
{
	let $schema-database-id := if ($database-config/db:schema-database/@name) then xdmp:database($database-config/db:schema-database/@name) else $default-schemas
	return
		admin:database-set-schema-database($admin-config, $database, $schema-database-id)
};


(:
  if the security database is 0, set it to 0.
  if the security database is set to an ID of another database in the import, get its new ID and set it to that
:)
declare function setup:set-security-database($admin-config as element(configuration), $database-config as element(db:database), $database as xs:unsignedLong) as element(configuration)
{
	let $security-database-id := if ($database-config/db:security-database/@name) then xdmp:database($database-config/db:security-database/@name) else $default-security
	return
		admin:database-set-security-database($admin-config, $database, $security-database-id)
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Creation of app servers
 ::)

declare function setup:create-appservers($import-config as element(configuration)) as item()*
{
	try {
		for $http-config in
			setup:get-http-servers-from-config($import-config)
		return
			setup:create-appserver($http-config),

		for $xdbc-config in
			setup:get-xdbc-servers-from-config($import-config)
		return
			setup:create-xdbcserver($xdbc-config)

	} catch ($e) {
		fn:concat("App servers creation failed: ", $e//err:format-string)
	}
};

declare function setup:create-appserver($server-config as element(gr:http-server)) as item()*
{
	let $server-name :=
		setup:get-server-name-from-http-config($server-config)
	return

	try {
		if (xdmp:servers()[$server-name = xdmp:server-name(.)]) then
			fn:concat("HTTP Server ", $server-name, " already exists, not recreated..")
		else
			let $admin-config :=
				admin:get-configuration()

			let $root := $server-config/gr:root[fn:string-length(.) > 0]
			let $root :=
				if ($root) then $root else "/"
			let $port :=
				xs:unsignedLong($server-config/gr:port)
			let $is-webdav :=
				xs:boolean($server-config/gr:webDAV)
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

			let $admin-config :=
				if ($is-webdav) then
					(: Note: database id is stored as modules is for webdav servers :)
					admin:webdav-server-create($admin-config, $default-group, $server-name, $root, $port, $modules-id)
				else
					admin:http-server-create($admin-config, $default-group, $server-name, $root, $port, $modules-id, $database-id)
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)

			return
				fn:concat("HTTP Server ", $server-name, " succesfully created..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("HTTP Server ", $server-name, " creation failed: ", $e//err:format-string)
	}
};

declare function setup:create-xdbcserver($server-config as element(gr:xdbc-server)) as item()*
{
	let $server-name :=
		setup:get-server-name-from-xdbc-config($server-config)
	return

	try {
		if (xdmp:servers()[$server-name = xdmp:server-name(.)]) then
			fn:concat("XDBC Server ", $server-name, " already exists, not recreated..")
		else
			let $admin-config :=
				admin:get-configuration()

			let $root := $server-config/gr:root[fn:string-length(.) > 0]
			let $root :=
				if ($root) then $root else "/"
			let $port :=
				xs:unsignedLong($server-config/gr:port)
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

			let $admin-config :=
				admin:xdbc-server-create($admin-config, $default-group, $server-name, $root, $port, $modules-id, $database-id)
			let $restart-hosts :=
				admin:save-configuration-without-restart($admin-config)

			return
				fn:concat("XDBC Server ", $server-name, " succesfully created..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("XDBC Server ", $server-name, " creation failed: ", $e//err:format-string)
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Configuration of app servers
 ::)

declare function setup:apply-appservers-settings($import-config as element(configuration)) as item()*
{
	try {
		for $http-config in
			setup:get-http-servers-from-config($import-config)
		return
			setup:configure-http-server($http-config),

		for $xdbc-config in
			setup:get-xdbc-servers-from-config($import-config)
		return
			setup:configure-xdbc-server($xdbc-config),

		for $task-config in
		  setup:get-task-servers-from-config($import-config)
		return
		  setup:configure-task-server($task-config)

	} catch ($e) {
		fn:concat("Applying servers settings failed: ", $e//err:format-string)
	}
};

declare function setup:configure-http-server($server-config as element(gr:http-server)) as item()*
{
	let $server-name := setup:get-server-name-from-http-config($server-config)
	let $server-id := xdmp:server($server-name)
	let $admin-config := setup:configure-server($server-config, $server-id)
	return
    xdmp:eval('
    import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
    import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

    declare namespace gr="http://marklogic.com/xdmp/group";

    declare variable $server-config as element() external;
    declare variable $server-name as xs:string external;
    declare variable $admin-config as element() external;
    declare variable $server-id external;
    declare variable $default-user external;
  	try {
  		let $default-user := if ($server-config/gr:default-user/@name) then xdmp:user($server-config/gr:default-user/@name) else $default-user
  		let $is-webdav :=
  			xs:boolean($server-config/gr:webDAV)

  		(: reconnect databases in case the appserver already existed :)
  		let $database-id :=
  			if ($server-config/gr:database/@name) then
  				xdmp:database($server-config/gr:database/@name)
  			else
  				0
  		let $_ := xdmp:log(text {"Modules db name:", $server-config/gr:modules/@name})
  		let $modules-id :=
  		  if ($server-config/gr:modules/@name eq "filesystem") then
  		    0
  			else if ($server-config/gr:modules/@name) then
  				xdmp:database($server-config/gr:modules/@name)
  			else
  				0
  		let $root := $server-config/gr:root[fn:string-length(.) > 0]
  		let $root :=
  			if ($root) then $root else "/"

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

  		let $admin-config := admin:appserver-set-default-user($admin-config, $server-id, $default-user)

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

  		let $restart-hosts :=
  			admin:save-configuration-without-restart($admin-config)
  		return
  			fn:concat("HTTP Server ", $server-name, " settings applied succesfully..", if ($restart-hosts) then " (note: restart required)" else ())

  	} catch ($e) {
  		fn:concat("Applying settings to HTTP Server ", $server-name, " failed: ", $e//err:format-string)
  	}',
  	(xs:QName("server-config"), $server-config,
  	 xs:QName("server-name"), $server-name,
     xs:QName("admin-config"), $admin-config,
     xs:QName("server-id"), $server-id,
     xs:QName("default-user"), $default-user))
};

declare function setup:configure-xdbc-server($server-config as element(gr:xdbc-server)) as item()*
{
	let $server-name :=
		setup:get-server-name-from-xdbc-config($server-config)
	return

	try {
		let $server-id := xdmp:server($server-name)
		let $admin-config := setup:configure-server($server-config, $server-id)

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
		let $admin-config :=
			admin:appserver-set-database($admin-config, $server-id, $database-id)
		let $admin-config :=
			admin:appserver-set-modules-database($admin-config, $server-id, $modules-id)

		let $restart-hosts :=
			admin:save-configuration-without-restart($admin-config)

		return
			fn:concat("XDBC Server ", $server-name, " settings applied succesfully..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
		fn:concat("Applying settings to XDBC Server ", $server-name, " failed: ", $e//err:format-string)
	}
};

declare function setup:configure-task-server($server-config as element(gr:task-server)) as item()*
{
	try {
		let $admin-config := admin:get-configuration()

		let $value as xs:boolean? := $server-config/gr:debug-allow
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-debug-allow($admin-config, $default-group, $value)
  		else
  			$admin-config

		let $value := $server-config/gr:debug-threads
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-debug-threads($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:default-time-limit
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-default-time-limit($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value as xs:boolean? := $server-config/gr:log-errors
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-log-errors($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:max-time-limit
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-max-time-limit($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:post-commit-trigger-depth
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-post-commit-trigger-depth($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:pre-commit-trigger-depth
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-pre-commit-trigger-depth($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:pre-commit-trigger-limit
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-pre-commit-trigger-limit($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value as xs:boolean? := $server-config/gr:profile-allow
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-profile-allow($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:queue-size
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-queue-size($admin-config, $default-group, $value)
  		else
  			$admin-config

  	let $value := $server-config/gr:threads
  	let $admin-config :=
  		if (fn:exists($value)) then
  		  admin:taskserver-set-threads($admin-config, $default-group, $value)
  		else
  			$admin-config

		let $restart-hosts :=
			admin:save-configuration-without-restart($admin-config)

		return
			fn:concat("Task Server settings applied succesfully..", if ($restart-hosts) then " (note: restart required)" else ())

	} catch ($e) {
	  xdmp:log($e),
		fn:concat("Applying settings to Task Server failed: ", $e//err:format-string)
	}
};

declare function setup:configure-server($server-config as element(), $server-id as xs:unsignedLong) as element(configuration)
{
	let $admin-config :=
		admin:get-configuration()
	let $last-login-id := if ($server-config/gr:last-login/@name) then xdmp:database($server-config/gr:last-login/@name) else 0

	let $admin-config := admin:appserver-set-last-login($admin-config, $server-id, $last-login-id)

	let $value := $server-config/gr:display-last-login[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-display-last-login($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:backlog[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-backlog($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:threads[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-threads($admin-config, $server-id, $server-config/gr:threads)
		else
			$admin-config

	let $value := $server-config/gr:request-timeout[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-request-timeout($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:keep-alive-timeout[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-keep-alive-timeout($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:max-time-limit[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-max-time-limit($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:default-time-limit[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-default-time-limit($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:pre-commit-trigger-depth[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-pre-commit-trigger-depth($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:pre-commit-trigger-limit[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-pre-commit-trigger-limit($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:collation[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-collation($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:authentication[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-authentication($admin-config, $server-id, $value)
		else
			$admin-config

	(: be carefull: privilege should be a lookup! :)
	(:

	let $value := $server-config/gr:privilege[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-privilege($admin-config, $server-id, $value)
		else
			$admin-config
	:)

	let $value := $server-config/gr:concurrent-request-limit[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-concurrent-request-limit($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:log-errors[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-log-errors($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:debug-allow[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-debug-allow($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:profile-allow[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-profile-allow($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:default-xquery-version[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-default-xquery-version($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:output-sgml-character-entities[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-output-sgml-character-entities($admin-config, $server-id, $value)
		else
			$admin-config

	let $value := $server-config/gr:output-encoding[fn:string-length(.) > 0]
	let $admin-config :=
		if ($value) then
			admin:appserver-set-output-encoding($admin-config, $server-id, $value)
		else
			$admin-config

  let $namespaces := $server-config/gr:namespaces/gr:namespace
  let $admin-config :=
    if ($namespaces) then
      let $old-ns := admin:appserver-get-namespaces($admin-config, $server-id)
      let $config :=
        (: First delete any namespace that matches the prefix and uri :)
        admin:appserver-delete-namespace($admin-config, $server-id,
          for $ns in $namespaces
          let $same-prefix := $old-ns[gr:prefix = $ns/gr:prefix][gr:namespace-uri ne $ns/gr:namespace-uri]
          return
            if ($same-prefix) then
              admin:group-namespace($same-prefix/gr:prefix, $same-prefix/gr:namespace-uri)
            else ()

        )
      return (: Then add in any namespace whose prefix isn't already defined :)
        admin:appserver-add-namespace($config, $server-id,
          for $ns in $namespaces
	return
            if ($old-ns[gr:prefix = $ns/gr:prefix][gr:namespace-uri = $ns/gr:namespace-uri]) then ()
            else
              admin:group-namespace($ns/gr:prefix, $ns/gr:namespace-uri)
        )
    else
		$admin-config


	(: TODO: schemas, request-blackouts :)

	return
		$admin-config
};

declare function setup:create-privileges($import-config as element(configuration))
{
  try {
    for $priv in setup:get-privileges-from-config($import-config)
    return
      setup:create-privilege($priv/sec:privilege-name,
                             $priv/sec:action,
                             $priv/sec:kind,
                             ())

  } catch ($e) {
    fn:concat("Privilege creation failed: ", $e//err:format-string)
  }
};

declare function setup:create-privilege($privilege-name as xs:string,
                                        $action as xs:string?,
                                        $kind as xs:string,
                                        $role-names as xs:string*)
{
  try {
    if (setup:get-privileges()/sec:privilege[sec:privilege-name = $privilege-name]) then
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $action as xs:string external;
                 declare variable $kind as xs:string external;
                 sec:remove-privilege($action, $kind)',
                (xs:QName("action"), $action,
                 xs:QName("kind"), $kind),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
    else (),
    xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
               declare variable $privilege-name as xs:string external;
               declare variable $action as xs:string external;
               declare variable $kind as xs:string external;
               declare variable $role-names as element() external;
               sec:create-privilege($privilege-name, $action, $kind, $role-names/*)',
              (xs:QName("privilege-name"), $privilege-name,
               xs:QName("action"), $action,
               xs:QName("kind"), $kind,
               xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
              <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
  }
  catch ($e) {
    fn:concat("Privilege ", $privilege-name, " creation failed: ", $e//err:format-string)
  }
};

declare function setup:create-roles($import-config as element(configuration))
{
  try {
    for $role in setup:get-roles-from-config($import-config)
    return
      setup:create-role($role/sec:role-name,
                        $role/sec:description,
                        $role/sec:role-names/sec:role-name,
                        $role/sec:permissions/*,
                        $role/sec:collections/*,
                        $role/sec:privileges/*)

  } catch ($e) {
    fn:concat("Role creation failed: ", $e//err:format-string)
  }
};

declare function setup:create-role($role-name as xs:string,
                                   $description as xs:string?,
                                   $role-names as xs:string*,
                                   $permissions as element(sec:permission)*,
                                   $collections as xs:string*,
                                   $privileges as element(sec:privilege)*)
{
  try {
    if (setup:get-roles(())/sec:role[sec:role-name = $role-name]) then
    (
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $role-name as xs:string external;
                 declare variable $description as xs:string external;
                 sec:role-set-description($role-name, $description)',
                (xs:QName("role-name"), $role-name,
                 xs:QName("description"), fn:string($description)),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>),
      if ($role-names) then
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $role-name as xs:string external;
                 declare variable $role-names as element() external;
                 sec:role-set-roles($role-name, $role-names/*)',
                (xs:QName("role-name"), $role-name,
                 xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      if ($permissions) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $role-name as xs:string external;
                   declare variable $permissions as element() external;
                   sec:role-set-default-permissions($role-name, $permissions/*)',
                  (xs:QName("role-name"), $role-name,
                   xs:QName("permissions"), <w>{for $p in $permissions return xdmp:permission($p/sec:role-name, $p/sec:capability)}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      if ($collections) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $role-name as xs:string external;
                   declare variable $collections as element() external;
                   sec:role-set-default-collections($role-name, $collections/*)',
                  (xs:QName("role-name"), $role-name,
                   xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      for $privilege in $privileges
      return
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $action as xs:string external;
                   declare variable $kind as xs:string external;
                   declare variable $role-name as xs:string external;
                   sec:privilege-add-roles($action, $kind, $role-name)',
                  (xs:QName("action"), $privilege/sec:action,
                   xs:QName("kind"), $privilege/sec:kind,
                   xs:QName("role-name"), $role-name),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
    )
    else
    (
      xdmp:log(text {"creating role:", $role-name}),
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $role-name as xs:string external;
                 declare variable $description as xs:string external;
                 declare variable $collections as element() external;
                 sec:create-role($role-name, $description, (), (), $collections/*)',
                (xs:QName("role-name"), $role-name,
                 xs:QName("description"), fn:string($description),
                 xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
(:
      if ($permissions) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $role-name as xs:string external;
                   declare variable $permissions as element() external;
                   sec:role-set-default-permissions($role-name, for $p in $permissions/* return xdmp:permission($p/sec:role-name, $p/sec:capability))',
                  (xs:QName("role-name"), $role-name,
                   xs:QName("permissions"), <w>{$permissions}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      if ($role-names) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $role-name as xs:string external;
                   declare variable $role-names as element() external;
                   sec:role-set-roles($role-name, $role-names/*)',
                  (xs:QName("role-name"), $role-name,
                   xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else ()
:)
    )
  }
  catch ($e) {
    xdmp:log($e),
    fn:concat("Role ", $role-name, " creation failed: ", $e//err:format-string)
  }
};

declare function setup:create-users($import-config as element(configuration))
{
  try {
    for $user in setup:get-users-from-config($import-config)
    return
      setup:create-user($user/sec:user-name,
                        $user/sec:description,
                        $user/sec:password,
                        $user/sec:role-names/*,
                        $user/sec:permissions/*,
                        $user/sec:collections/*)

  } catch ($e) {
    xdmp:log($e),
    fn:concat("User creation failed: ", $e//err:format-string)
  }
};

declare function setup:create-user($user-name as xs:string,
                                   $description as xs:string?,
                                   $password as xs:string,
                                   $role-names as xs:string*,
                                   $permissions as element(sec:permission)*,
                                   $collections as xs:string* )
{
  try {
    if (setup:get-users(())/sec:user[sec:user-name = $user-name]) then
    (
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $user-name as xs:string external;
                 declare variable $description as xs:string external;
                 sec:user-set-description($user-name, $description)',
                (xs:QName("user-name"), $user-name,
                 xs:QName("description"), fn:string($description)),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>),

      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                 declare variable $user-name as xs:string external;
                 declare variable $password as xs:string external;
                 sec:user-set-password($user-name, $password)',
                (xs:QName("user-name"), $user-name,
                 xs:QName("password"), fn:string($password)),
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>),

      if ($role-names) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $user-name as xs:string external;
                   declare variable $role-names as element() external;
                   sec:user-set-roles($user-name, $role-names/*)',
                  (xs:QName("user-name"), $user-name,
                   xs:QName("role-names"), <w>{for $r in $role-names return <w>{$r}</w>}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      if ($permissions) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $user-name as xs:string external;
                   declare variable $permissions as element() external;
                   sec:user-set-default-permissions($user-name, $permissions/*)',
                  (xs:QName("user-name"), $user-name,
                   xs:QName("permissions"), <w>{for $p in $permissions return xdmp:permission($p/sec:role-name, $p/sec:capability)}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else (),

      if ($collections) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $user-name as xs:string external;
                   declare variable $collections as element() external;
                   sec:user-set-default-collections($user-name, $collections/*)',
                  (xs:QName("user-name"), $user-name,
                   xs:QName("collections"), <w>{for $c in $collections return <w>{$c}</w>}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else ()
    )
    else
    (
      xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
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
                <options xmlns="xdmp:eval"><database>{$default-security}</database></options>),
      if ($permissions) then
        xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                   declare variable $user-name as xs:string external;
                   declare variable $permissions as element() external;
                   sec:user-set-default-permissions($user-name, for $p in $permissions/* return xdmp:permission($p/sec:role-name, $p/sec:capability))',
                  (xs:QName("user-name"), $user-name,
                   xs:QName("permissions"), <w>{$permissions}</w>),
                  <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
      else ()
    )
  }
  catch ($e) {
    fn:concat("User ", $user-name, " creation failed: ", $e//err:format-string)
  }
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Export configuration to XML
 ::)
declare function setup:get-configuration($databases as xs:string*,
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
			</http-servers>
		,
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
  xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $id as xs:unsignedLong external;
             sec:get-role-names($id)',
             (xs:QName("id"), $id),
             <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
};

declare function setup:get-role-privileges($role as element(sec:role)) as element(sec:privilege)* {
  xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
             declare variable $role-name as xs:string external;
             sec:role-privileges($role-name)',
            (xs:QName("role-name"), fn:string($role/sec:role-name)),
            <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)[sec:role-ids/sec:role-id = $role/sec:role-id]
};

declare function setup:get-privileges() as element(sec:privileges)? {
  <privileges xmlns="http://marklogic.com/xdmp/security">
  {
    xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                             /sec:privilege',
                            (),
                            <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
  }
  </privileges>
};

declare function setup:get-users($ids as xs:unsignedLong*) as element(sec:users)? {
  let $users := xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                           /sec:user',
                           (),
                           <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
  let $users :=
    if ($ids) then $users[sec:user-id = $ids]
    else $users
  where $users
  return
    <users xmlns="http://marklogic.com/xdmp/security">
    {
      for $user in $users
      return
        element sec:user {
          $user/@*,
          $user/*[fn:not(self::sec:user-id) and
                  fn:not(self::sec:digest-password) and
                  fn:not(self::sec:password) and
                  fn:not(self::sec:role-ids) and
                  fn:not(self::sec:permissions)],

          element sec:password {()},

          element sec:role-names {
            for $id in $user/sec:role-ids/*
            return
              element sec:role-name {setup:get-role-name($id)}
          },

          element sec:permissions {
            for $perm in $user/sec:permissions/sec:permission
            return
              element sec:permission {
                $perm/sec:capability,
                element sec:role-name {setup:get-role-name($perm/sec:role-id)}
              }
          }
        }
    }</users>
};

declare function setup:get-roles($ids as xs:unsignedLong*) as element(sec:roles)? {
  let $roles := xdmp:eval('import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
                           /sec:role',
                          (),
                          <options xmlns="xdmp:eval"><database>{$default-security}</database></options>)
  let $roles :=
    if ($ids) then $roles[sec:role-id = $ids]
    else $roles
  where $roles
  return
    <roles xmlns="http://marklogic.com/xdmp/security">
    {
      for $role in $roles
      return
        element sec:role {
          $role/@*,
          $role/*[fn:not(self::sec:role-id) and
                  fn:not(self::sec:role-ids) and
                  fn:not(self::sec:permissions)],
          element sec:role-names {
            for $id in $role/sec:role-ids/*
            return
              element sec:role-name {setup:get-role-name($id)}
          },

          element sec:permissions {
            for $perm in $role/sec:permissions/sec:permission
            return
              element sec:permission {
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

declare function setup:get-mimetypes($names as xs:string*) as element(mt:mimetypes)? {
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

declare function setup:resolve-database-id-to-name($node as element()) as element()? {
	if (fn:data($node) ne 0) then
		element {fn:node-name($node)} {
			attribute {xs:QName("name")} { xdmp:database-name(fn:data($node)) }
		}
	else ()
};

declare function setup:resolve-forest-id-to-name($node as element()) as element()? {
	if (fn:data($node) ne 0) then
		element {fn:node-name($node)} {
			attribute {xs:QName("name")} { xdmp:forest-name(fn:data($node)) }
		}
	else ()
};

declare function setup:resolve-host-id-to-name($node as element()) as element()? {
	if (fn:data($node) ne 0) then
		element {fn:node-name($node)} {
			attribute {xs:QName("name")} { xdmp:host-name(fn:data($node)) }
		}
	else ()
};

declare function setup:resolve-user-id-to-name($node as element()) as element()? {
	if (fn:data($node) ne 0) then
		element {fn:node-name($node)} {
			attribute {xs:QName("name")} { setup:user-name(fn:data($node)) }
		}
	else ()
};

declare function setup:resolve-ids-to-names($nodes as item()*) as item()* {
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
					element {fn:node-name($node)} {
						$node/@*,
						setup:resolve-ids-to-names($node/node())
					}
				else ()

			case document-node() return
				document {
					setup:resolve-ids-to-names($node/node())
				}

			default return
				$node
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Stripping default properties
 ::)

declare function setup:default-http-server() as element(gr:http-server)
{
	(: Just pretend to create, do not save! :)
	let $admin-config := admin:get-configuration()
	let $admin-config :=
		admin:http-server-create($admin-config, $default-group, "default", "/", 19999, $default-modules, $default-database)
	return
		$admin-config//gr:http-servers/gr:http-server[gr:http-server-name eq "default"]
};

declare function setup:strip-default-properties-from-http-server($node as element(gr:http-server)) as element(gr:http-server) {
	element { fn:node-name($node) } {
		$node/@*,

		let $default-properties :=
			setup:default-http-server()/*

		for $property in $node/*
		where
			fn:not($default-properties[fn:deep-equal(., $property)])
		and
			fn:not(xs:boolean($node/gr:webDAV) and $property/self::gr:compute-content-length)
		and
			fn:not($property/self::gr:http-server-id)
		return
			$property
	}
};

declare function setup:default-xdbc-server() as element(gr:xdbc-server)
{
	(: Just pretend to create, do not save! :)
	let $admin-config := admin:get-configuration()
	let $admin-config :=
		admin:xdbc-server-create($admin-config, $default-group, "default", "/", 19999, $default-modules, $default-database)
	return
		$admin-config//gr:xdbc-servers/gr:xdbc-server[gr:xdbc-server-name eq "default"]
};

declare function setup:strip-default-properties-from-xdbc-server($node as element(gr:xdbc-server)) as element(gr:xdbc-server) {
	element { fn:node-name($node) } {
		$node/@*,

		let $default-properties :=
			setup:default-xdbc-server()/*

		for $property in $node/*
		where
			fn:not($default-properties[fn:deep-equal(., $property)])
		and
			fn:not($property/self::gr:xdbc-server-id)
		return
			$property
	}
};

declare function setup:default-database() as element(db:database)
{
	(: Just pretend to create, do not save! :)
	let $admin-config := admin:get-configuration()
	let $admin-config :=
		admin:database-create($admin-config, "default", $default-security, $default-schemas)
	return
		$admin-config//db:databases/db:database[db:database-name eq "default"]
};

declare function setup:strip-default-properties-from-database($node as element(db:database)) as element(db:database) {
	element { fn:node-name($node) } {
		$node/@*,

		let $default-properties :=
			setup:default-database()/*

		for $property in $node/*
		where
			fn:not($default-properties[fn:deep-equal(., $property)])
		and
			fn:not($property/self::db:database-id)
		return
			$property
	}
};

declare function setup:default-forest() as element(as:assignment)
{
	(: Just pretend to create, do not save! :)
	let $admin-config := admin:get-configuration()
	let $admin-config :=
		admin:forest-create($admin-config, "default", $default-host, ())
	return
		$admin-config//as:assignments/as:assignment[as:forest-name eq "default"]
};

declare function setup:strip-default-properties-from-forest($node as element(as:assignment)) as element(as:assignment) {
	element { fn:node-name($node) } {
		$node/@*,

		let $default-properties :=
			setup:default-forest()/*

		for $property in $node/*
		where
			fn:not($default-properties[fn:deep-equal(., $property)])
		and
			fn:not($property/self::as:forest-id)
		return
			$property
	}
};

(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Accessing import-config
 ::)

declare function setup:get-mimetypes-from-config($import-config as element(configuration)) as element(mt:mimetype)*
{
	$import-config//mt:mimetypes/mt:mimetype
};

declare function setup:get-forests-from-config($import-config as element(configuration)) as element(as:assignment)*
{
	$import-config//as:assignments/as:assignment
};

declare function setup:get-forest-name-from-forest-config($forest-config as element(as:assignment)) as xs:string?
{
	fn:data(
		$forest-config/as:forest-name[fn:string-length(.) > 0]
	)
};

declare function setup:get-data-directory-from-forest-config($forest-config as element(as:assignment)) as xs:string?
{
	fn:data(
		$forest-config/as:data-directory[fn:string-length(.) > 0]
	)
};

declare function setup:get-databases-from-config($import-config as element(configuration)) as element(db:database)*
{
  for $db in $import-config//db:databases/db:database
  return
    if (fn:exists($db/@import)) then
      element db:database {
        $db/*,
        let $ignore := $db/*/fn:node-name(.)
        return
          $import-config//db:databases/db:database[db:database-name eq $db/@import]/*[fn:not(fn:node-name(.) = $ignore)]
      }
    else
      $db
};

declare function setup:get-database-name-from-database-config($database-config as element(db:database)) as xs:string?
{
	fn:data(
		$database-config/db:database-name[fn:string-length(.) > 0]
	)
};

declare function setup:get-forest-refs-from-database-config($database-config as element(db:database)) as element(db:forest-id)*
{
	$database-config/db:forests/db:forest-id
};

declare function setup:get-forest-from-config($import-config as element(configuration), $forest-ref as element(db:forest-id)) as element(as:assignment)?
{
	$import-config//as:assignment[as:forest-id eq $forest-ref]
};

declare function setup:get-http-servers-from-config($import-config as element(configuration)) as element(gr:http-server)*
{
	$import-config//gr:http-servers/gr:http-server
};

declare function setup:get-server-name-from-http-config($server-config as element(gr:http-server)) as xs:string?
{
	fn:data(
		$server-config/gr:http-server-name[fn:string-length(.) > 0]
	)
};

declare function setup:get-xdbc-servers-from-config($import-config as element(configuration)) as element(gr:xdbc-server)*
{
	$import-config//gr:xdbc-servers/gr:xdbc-server
};

declare function setup:get-task-servers-from-config($import-config as element(configuration)) as element(gr:task-server)*
{
  $import-config//gr:task-server
};

declare function setup:get-server-name-from-xdbc-config($server-config as element(gr:xdbc-server)) as xs:string?
{
	fn:data(
		$server-config/gr:xdbc-server-name[fn:string-length(.) > 0]
	)
};

declare function setup:get-servers-from-config($import-config as element(configuration)) as item()*
{
	for $server in
		$import-config//gr:http-servers/gr:http-server
	return (
		$server/gr:http-server-name,

		if (xs:boolean($server/gr:webDAV)) then
			"WebDAV"
		else
			"HTTP",

		fn:data($server/gr:port)
    ),

	for $server in
		$import-config//gr:xdbc-servers/gr:xdbc-server
	return (
		$server/gr:xdbc-server-name,

		"XDBC",

		fn:data($server/gr:port)
	)
};

declare function setup:get-setting-from-database-config($database-config as element(db:database), $setting-name as xs:string) as element()?
{
	xdmp:value(fn:concat("$database-config//*:", $setting-name))
};

declare function setup:get-setting-from-database-config-as-string($database-config as element(db:database), $setting-name as xs:string) as xs:string?
{
	let $setting := setup:get-setting-from-database-config($database-config, $setting-name)
	where $setting
	return
		fn:string($setting)
};

declare function setup:get-setting-from-database-config-as-boolean($database-config as element(db:database), $setting-name as xs:string) as xs:boolean?
{
	let $str := setup:get-setting-from-database-config-as-string($database-config, $setting-name)
	where $str
	return
		setup:to-boolean($str)
};

declare function setup:get-privileges-from-config($import-config as element(configuration)) as element(sec:privilege)*
{
  $import-config//sec:privileges/sec:privilege
};

declare function setup:get-roles-from-config($import-config as element(configuration)) as element(sec:role)*
{
  $import-config//sec:roles/sec:role
};

declare function setup:get-users-from-config($import-config as element(configuration)) as element(sec:user)*
{
  $import-config//sec:users/sec:user
};


(::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 :: Utility functions
 ::)

declare function setup:read-config-file($filename as xs:string) as document-node()
{
	xdmp:security-assert("http://marklogic.com/xdmp/privileges/admin-module-read", "execute"),
	xdmp:read-cluster-config-file($filename)
};

declare function setup:to-boolean($value as xs:string) as xs:boolean
{
	fn:boolean(fn:lower-case($value) = ("1", "y", "yes", "true"))
};

declare function setup:user-name($user-id as xs:unsignedLong?) as xs:string {
	let $user-id :=
		if ($user-id) then
			$user-id
		else
			fn:data(xdmp:get-request-user())
	return
		xdmp:eval(
			'
				xquery version "1.0-ml";
				import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

				declare variable $user-id as xs:unsignedLong external;
				sec:get-user-names($user-id)
			',
			(xs:QName("user-id"), $user-id),
			<options xmlns="xdmp:eval"><database>{$default-security}</database></options>
		)
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
      	border:0;			/* This removes the border around the viewport in old versions of IE */
      	width:100%;
      	background:#fff;
      	min-width:600px;    	/* Minimum width of layout - remove line if not required */
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
      	position:relative;	/* This fixes the IE7 overflow hidden bug */
      	clear:both;
      	float:left;
      	width:100%;			/* width of whole page */
      	overflow:hidden;		/* This chops off any overhanging divs */
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
      	background:#fff;		/* right column background colour */
      }}
      .leftmenu .colleft {{
      	right:75%;			/* right column width */
      	background:#ADD8E6;	/* left column background colour */
      }}
      .leftmenu .col1 {{
      	width:71%;			/* right column content width */
      	left:102%;			/* 100% plus left column left padding */
      }}
      .leftmenu .col2 {{
      	width:21%;			/* left column content width (column width minus left and right padding) */
      	left:6%;			/* (right column left and right padding) plus (left column left padding) */
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
			()
		,

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
