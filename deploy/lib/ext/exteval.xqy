xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/exteval";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:output "indent=yes";
declare option xdmp:output "indent-untyped=yes";
declare option xdmp:mapping "false";

(: One of $sid or $dbid must not be empty :)
declare function ext:get-eval-options(
    $sid as xs:unsignedLong?,
    $dbid as xs:unsignedLong?
) as element()
{
    let $config := admin:get-configuration()
    let $database-id :=
    if ( $sid )
    then ( admin:appserver-get-database( $config, $sid))
    else if ( $dbid )
        then ( $dbid )
        else ( (: This REST framework doesn't return 400 :)
               error((),"REQUIREDPARAM","sid or dbid") )
    let $server-id :=
        if ( $sid )
        then ( $sid )
        else ( xdmp:server() )
    let $collation :=
        try {
            admin:appserver-get-collation($config, $server-id) }
        catch ($ex) {
            if ($ex/error:code eq 'SEC-PRIV')
            then default-collation()
            else xdmp:rethrow()
        }
    let $modules-id :=
        try {
            admin:appserver-get-modules-database($config, $server-id) }
        catch ($ex) {
            if ($ex/error:code eq 'SEC-PRIV')
            then xdmp:modules-database()
            else xdmp:rethrow()
        }
    let $xquery-version :=
        try {
            admin:appserver-get-default-xquery-version($config, $server-id) }
        catch ($ex) {
            if ($ex/error:code eq 'SEC-PRIV')
            then 'app-server'
            else xdmp:rethrow()
        }
    let $modules-root :=
        try {
            admin:appserver-get-root($config, $server-id) }
        catch ($ex) {
            if ($ex/error:code eq 'SEC-PRIV')
            then xdmp:modules-root()
            else xdmp:rethrow()
        }
    let $options :=
        (: avoid setting options unless needed, for more flexible security :)
        <options xmlns="xdmp:eval">{
            if ($database-id eq xdmp:database()) then ()
            else element database { $database-id },
            if ($modules-id eq xdmp:modules-database()) then ()
            else element modules { $modules-id },
            if ($collation eq default-collation()) then ()
            else element default-collation { $collation },
            if ($xquery-version eq xdmp:xquery-version()) then ()
            else element default-xquery-version { $xquery-version },
            (: we should always have a root path, but better safe than sorry :)
            if (empty($modules-root) or $modules-root eq xdmp:modules-root()) then ()
            else element root { $modules-root },
            element isolation { "different-transaction" },
            if (xdmp:database-is-replica($database-id))
            then element timestamp {xdmp:database-nonblocking-timestamp($database-id)}
            else (),
            element ignore-amps { "true" }
        }</options>
    return
        $options
};

declare 
%roxy:params("sid=xs:unsignedLong?", "dbid=xs:unsignedLong?", "querytype=xs:string?", "action=xs:string?")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/json; charset=utf-8"),
  document {
    try {
      
      let $sid := for $p in map:get($params, "sid") return xs:unsignedLong($p)
      let $dbid := for $p in map:get($params, "dbid") return xs:unsignedLong($p)
      let $query := $input
      
      let $eval-opts := ext:get-eval-options($sid, $dbid)
      let $results := xdmp:eval($query, (), $eval-opts)
      return
        xdmp:to-json($results),
        
      xdmp:set-response-code(200, "OK")
      
    } catch ($e) {
      xdmp:log($e),
      xdmp:set-response-code(500, $e/error:format-string),
      json:transform-to-json(<error>{ $e/error:format-string }</error>, json:config("custom"))
    }
  }
};
