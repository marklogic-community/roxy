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

module namespace c = "http://marklogic.com/roxy/controller/test-request";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

declare option xdmp:mapping "false";

declare private function c:date-as-float()
{
  req:get("dt", "type=xs:float")
};

declare private function c:invalid-number()
{
  req:get("invalidnumber", "type=xs:int")
};

declare private function c:test-missing-param()
{
  req:required("bogus")
};

declare private function c:test-max-count()
{
  test:assert-equal((), req:get("single", "max-count=1"))
};

declare private function c:test-required-verb()
{
  test:assert-equal((), req:require-verb("POST"))
};

declare private function c:busted-xml()
{
  test:assert-equal(<busted-xml/>, req:get("x2", "type=xml"))
};

declare function c:test1() as item()*
{
  <results>
  {
    try
    {
      test:assert-true(fn:empty(req:get("bogus"))),
      test:assert-equal("yes", req:get("valid")),
      test:assert-true(req:get("dt", "type=xs:dateTime") instance of xs:dateTime),
      test:assert-false(req:get("dt", "type=xs:dateTime") instance of xs:string),
      test:assert-throws-error(xdmp:function(xs:QName("c:date-as-float")), "INVALID-REQUEST-PARAMETER"),
      test:assert-equal(1234, req:get("number", "type=xs:int")),
      test:assert-throws-error(xdmp:function(xs:QName("c:invalid-number")), "INVALID-REQUEST-PARAMETER"),
      test:assert-equal(("a", "b", "c"), req:get("sequence", "type=xs:string+")),
      test:assert-equal(("a", "b", "c"), req:get("sequence", "type=xs:string*")),
      test:assert-equal((), req:get("empty-sequence", "type=xs:string*")),
      test:assert-equal('has"quote"indeed', req:get("hasquote", "type=xs:string")),
      test:assert-equal("yes", req:required("valid")),
      test:assert-throws-error(xdmp:function(xs:QName("c:test-missing-param")), "MISSING-CONTROLLER-PARAM"),
      test:assert-equal((), req:require-verb("GET")),
      test:assert-throws-error(xdmp:function(xs:QName("c:test-required-verb")), "INVALID-VERB"),
      test:assert-throws-error(xdmp:function(xs:QName("c:test-max-count")), "TOO-MANY-VALUES"),
      test:assert-equal(<test/>, req:get("x1", "type=xml")),
      test:assert-throws-error(xdmp:function(xs:QName("c:busted-xml")), "INVALID-REQUEST-PARAMETER"),
      test:assert-equal("", req:get("empty", "type=xs:string")),
      test:assert-equal("", req:get("empty", ("type=xs:string", "allow-empty=true"))),
      test:assert-equal((), req:get("empty", ("type=xs:string", "allow-empty=false"))),
      test:assert-equal("yo!", req:get("empty", "yo!", ("type=xs:string", "allow-empty=false")))
    }
    catch($ex)
    {
      test:fail($ex)
    }
  }
  </results>
};