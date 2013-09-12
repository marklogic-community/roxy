xquery version "1.0-ml";

module namespace t="http://marklogic.com/roxy/test";

import module "http://marklogic.com/roxy/test" at "/test/lib/test-helper.xqy";

import module namespace form = "http://marklogic.com/roxy/form-lib" at "/app/views/helpers/form-lib.xqy";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare function t:checkbox()
{
  let $cb := form:checkbox("cb-label", "cb-name", fn:true(), "cb-class", "cb-id")
  return (
    t:assert-equal("cb-label", $cb/xhtml:label/fn:string()),
    t:assert-equal("cb-name", $cb/xhtml:input/@name/fn:string()),
    t:assert-exists($cb/xhtml:input/@checked),
    t:assert-equal("cb-class", $cb/@class/fn:string()),
    t:assert-equal("cb-id", $cb/xhtml:label/@for/fn:string()),
    t:assert-equal("cb-id", $cb/xhtml:input/@id/fn:string()),
    t:assert-equal("checkbox", $cb/xhtml:input/@type/fn:string())
  ),

  let $cb := form:checkbox("cb-label2", "cb-name2", fn:false(), "cb-class2", "cb-id2")
  return (
    t:assert-equal("cb-label2", $cb/xhtml:label/fn:string()),
    t:assert-equal("cb-name2", $cb/xhtml:input/@name/fn:string()),
    t:assert-not-exists($cb/xhtml:input/@checked),
    t:assert-equal("cb-class2", $cb/@class/fn:string()),
    t:assert-equal("cb-id2", $cb/xhtml:label/@for/fn:string()),
    t:assert-equal("cb-id2", $cb/xhtml:input/@id/fn:string()),
    t:assert-equal("checkbox", $cb/xhtml:input/@type/fn:string())
  )
};

declare function t:radio()
{
  let $cb := form:radio("cb-label", "cb-name", fn:true(), "cb-class", "cb-id")
  return (
    t:assert-equal("cb-label", $cb/xhtml:label/fn:string()),
    t:assert-equal("cb-name", $cb/xhtml:input/@name/fn:string()),
    t:assert-exists($cb/xhtml:input/@checked),
    t:assert-equal("cb-class", $cb/@class/fn:string()),
    t:assert-equal("cb-id", $cb/xhtml:label/@for/fn:string()),
    t:assert-equal("cb-id", $cb/xhtml:input/@id/fn:string()),
    t:assert-equal("radio", $cb/xhtml:input/@type/fn:string())
  ),

  let $cb := form:radio("cb-label2", "cb-name2", fn:false(), "cb-class2", "cb-id2")
  return (
    t:assert-equal("cb-label2", $cb/xhtml:label/fn:string()),
    t:assert-equal("cb-name2", $cb/xhtml:input/@name/fn:string()),
    t:assert-not-exists($cb/xhtml:input/@checked),
    t:assert-equal("cb-class2", $cb/@class/fn:string()),
    t:assert-equal("cb-id2", $cb/xhtml:label/@for/fn:string()),
    t:assert-equal("cb-id2", $cb/xhtml:input/@id/fn:string()),
    t:assert-equal("radio", $cb/xhtml:input/@type/fn:string())
  )
};

declare function t:text-area()
{
  let $input := form:text-area("input-label", "input-name", "input-class")
  return (
    t:assert-equal("input-label", $input/xhtml:label/fn:string()),
    t:assert-equal("input-name", $input/xhtml:textarea/@name/fn:string()),
    t:assert-equal("input-class", $input/@class/fn:string()),
    t:assert-equal("", $input/xhtml:textarea/fn:string())
  ),

  let $input := form:text-area("input-label", "input-name", "input-class", "input-value")
  return (
    t:assert-equal("input-label", $input/xhtml:label/fn:string()),
    t:assert-equal("input-name", $input/xhtml:textarea/@name/fn:string()),
    t:assert-equal("input-class", $input/@class/fn:string()),
    t:assert-equal("input-value", $input/xhtml:textarea/fn:string())
  )
};

declare function t:text-input()
{
  let $input := form:text-input("input-label", "input-name", "input-class")
  return (
    t:assert-equal("input-label", $input/xhtml:label/fn:string()),
    t:assert-equal("input-name", $input/xhtml:input/@name/fn:string()),
    t:assert-equal("input-class", $input/@class/fn:string()),
    t:assert-equal("text", $input/xhtml:input/@type/fn:string()),
    t:assert-equal("", $input/xhtml:input/@value/fn:string())
  ),

  let $input := form:text-input("input-label", "input-name", "input-class", "input-value")
  return (
    t:assert-equal("input-label", $input/xhtml:label/fn:string()),
    t:assert-equal("input-name", $input/xhtml:input/@name/fn:string()),
    t:assert-equal("input-class", $input/@class/fn:string()),
    t:assert-equal("text", $input/xhtml:input/@type/fn:string()),
    t:assert-equal("input-value", $input/xhtml:input/@value/fn:string())
  )
};