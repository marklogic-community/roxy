xquery version "1.0-ml";

import module namespace pager = "http://marklogic.com/roxy/pager-lib" at "/app/views/helpers/pager-lib.xqy";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

test:assert-equal(
  (
    <span class="page-numbers" xmlns="http://www.w3.org/1999/xhtml">Results <b>1</b> to <b>100</b> of <b>1001</b></span>,
    <span class="next" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=101">»</a></span>
  ),
  pager:pagination(<response xmlns="http://marklogic.com/appservices/search" start="1" total="1001" page-length="100"/>, "/search", "index")),

test:assert-equal(
  (
    <span class="previous" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=701">«</a></span>,
    <span class="page-numbers" xmlns="http://www.w3.org/1999/xhtml">Results <b>801</b> to <b>900</b> of <b>1001</b></span>,
    <span class="next" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=901">»</a></span>
  ),
  pager:pagination(<response xmlns="http://marklogic.com/appservices/search" start="801" total="1001" page-length="100"/>, "/search", "index")),

test:assert-equal(
  (
    <span class="previous" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=801">«</a></span>,
    <span class="page-numbers" xmlns="http://www.w3.org/1999/xhtml">Results <b>901</b> to <b>1000</b> of <b>1001</b></span>,
    <span class="next" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=1001">»</a></span>
  ),
  pager:pagination(<response xmlns="http://marklogic.com/appservices/search" start="901" total="1001" page-length="100"/>, "/search", "index")),

test:assert-equal(
  (
    <span class="previous" xmlns="http://www.w3.org/1999/xhtml"><a href="/search?index=901">«</a></span>,
    <span class="page-numbers" xmlns="http://www.w3.org/1999/xhtml">Results <b>1001</b> to <b>1001</b> of <b>1001</b></span>
  ),
  pager:pagination(<response xmlns="http://marklogic.com/appservices/search" start="1001" total="1001" page-length="100"/>, "/search", "index"))