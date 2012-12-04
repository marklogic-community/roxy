xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";
import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p = "http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
import module namespace u = "http://marklogic.com/roxy/util" at "/roxy/lib/util.xqy";

declare option xdmp:mapping "false";

declare function t:setup()
{
  if (xdmp:modules-database() eq 0) then
    t:fail("You must run this test from a modules database.")
  else (),

  if (xdmp:triggers-database() eq 0) then
    t:fail("You must configure a triggers database to run this test.")
  else (),

  cpf:clean-cpf()
};

declare function t:teardown()
{
  if (xdmp:triggers-database() eq 0) then
    t:fail("You must configure a triggers database to run this test.")
  else
    cpf:clean-cpf()
};

declare function t:load-from-config()
{
  let $get-domain := function() {
    xdmp:eval('
      xquery version "1.0-ml";
      import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
      dom:get( "My Test Domain" )',(),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
      </options>)
  }
  return
    t:assert-throws-error($get-domain, "CPF-DOMAINNOTFOUND"),

  cpf:load-from-config(
    <config xmlns="http://marklogic.com/roxy/cpf">
      <domains>
        <domain>
          <name>My Test Domain</name>
          <description>This domain is awesome!!!</description>
          <pipelines>
            <pipeline>{xdmp:modules-root()}test/roxy/lib/data/_test-pipeline1.xml</pipeline>
          </pipelines>
          <system-pipelines>
            <system-pipeline>Status Change Handling</system-pipeline>
            <system-pipeline>A fake name that doesn't exist</system-pipeline>
          </system-pipelines>
          <scope>
            <type>document</type>
            <uri>/stuff.xml</uri>
            <depth/>
          </scope>
          <context>
            <modules-database>{xdmp:database-name(xdmp:modules-database())}</modules-database>
            <root>/</root>
          </context>
          <restart-user>{$c:USER}</restart-user>
          <permissions>
            <permission>
              <capability>read</capability>
              <role-name>admin</role-name>
            </permission>
          </permissions>
        </domain>
      </domains>
    </config>),

  let $dom :=
    xdmp:eval('
      xquery version "1.0-ml";
      import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
      dom:get( "My Test Domain" )',(),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
      </options>)
  let $pipelines :=
    for $p in $dom/dom:pipeline
    return
      xdmp:eval(
        fn:concat(
          'import module namespace p = "http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
           p:get-by-id(', fn:string($p), ')'), (),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
        </options>)
  return
  (
    t:assert-equal("My Test Domain", fn:string($dom/dom:domain-name)),
    t:assert-equal("This domain is awesome!!!", fn:string($dom/dom:domain-description)),
    t:assert-equal("document", fn:string($dom/dom:domain-scope/dom:document-scope)),
    t:assert-equal("/stuff.xml", fn:string($dom/dom:domain-scope/dom:uri)),
    t:assert-equal(xdmp:database-name(xdmp:modules-database()), xdmp:database-name($dom/dom:evaluation-context/dom:database)),
    t:assert-equal("/", fn:string($dom/dom:evaluation-context/dom:root)),
    t:assert-equal(2, fn:count($pipelines)),
    t:assert-equal(1, fn:count($pipelines/p:pipeline-name[. = "Test Pipeline 1"])),
    t:assert-equal(1, fn:count($pipelines/p:pipeline-name[. = "Status Change Handling"]))
  )
};
