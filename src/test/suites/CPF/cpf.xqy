xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";

if (xdmp:triggers-database() ne 0) then
  cpf:clean-cpf()
else ()
;

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p = "http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare function local:get-domain()
{
  xdmp:eval('
    xquery version "1.0-ml";
    import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
    dom:get( "My Test Domain" )',(),
    <options xmlns="xdmp:eval">
		  <database>{xdmp:triggers-database()}</database>
	  </options>)
};

if (xdmp:triggers-database() ne 0) then
  test:assert-throws-error(xdmp:function(xs:QName("local:get-domain")), "CPF-DOMAINNOTFOUND")
else ()
;

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";

import module namespace c = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";

if (xdmp:triggers-database() ne 0) then
  cpf:load-from-config(
  <config xmlns="http://marklogic.com/roxy/cpf">
    <domains>
      <domain>
        <name>My Test Domain</name>
        <description>This domain is awesome!!!</description>
        <pipelines>
          <pipeline>{xdmp:modules-root()}test/suites/CPF/_test-pipeline1.xml</pipeline>
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
  </config>)
else ()
;

import module namespace cpf = "http://marklogic.com/roxy/cpf" at "/roxy/lib/cpf.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";
import module namespace p = "http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

if (xdmp:triggers-database() ne 0) then
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
    test:assert-equal("My Test Domain", fn:string($dom/dom:domain-name)),
    test:assert-equal("This domain is awesome!!!", fn:string($dom/dom:domain-description)),
    test:assert-equal("document", fn:string($dom/dom:domain-scope/dom:document-scope)),
    test:assert-equal("/stuff.xml", fn:string($dom/dom:domain-scope/dom:uri)),
    test:assert-equal(xdmp:database-name(xdmp:modules-database()), xdmp:database-name($dom/dom:evaluation-context/dom:database)),
    test:assert-equal("/", fn:string($dom/dom:evaluation-context/dom:root)),
    test:assert-equal(2, fn:count($pipelines)),
    test:assert-equal(1, fn:count($pipelines/p:pipeline-name[. = "Test Pipeline 1"])),
    test:assert-equal(1, fn:count($pipelines/p:pipeline-name[. = "Status Change Handling"]))
  )
else()