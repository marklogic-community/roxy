xquery version "1.0-ml";

import module namespace pager = "http://marklogic.com/roxy/pager-lib" at "/app/views/helpers/pager-lib.xqy";

import module namespace test="http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>1</current-page>
    <total-pages>4</total-pages>
    <page-length>100</page-length>
    <previous-index/>
    <previous-page/>
    <next-index>101</next-index>
    <next-page>2</next-page>
    <showing>
      <start>1</start>
      <end>100</end>
      <total>301</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="1" total="301" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>2</current-page>
    <total-pages>4</total-pages>
    <page-length>100</page-length>
    <previous-index>1</previous-index>
    <previous-page>1</previous-page>
    <next-index>201</next-index>
    <next-page>3</next-page>
    <showing>
      <start>101</start>
      <end>200</end>
      <total>301</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="101" total="301" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>3</current-page>
    <total-pages>4</total-pages>
    <page-length>100</page-length>
    <previous-index>101</previous-index>
    <previous-page>2</previous-page>
    <next-index>301</next-index>
    <next-page>4</next-page>
    <showing>
      <start>201</start>
      <end>300</end>
      <total>301</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="201" total="301" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>4</current-page>
    <total-pages>4</total-pages>
    <page-length>100</page-length>
    <previous-index>201</previous-index>
    <previous-page>3</previous-page>
    <next-index/>
    <next-page/>
    <showing>
      <start>301</start>
      <end>301</end>
      <total>301</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="301" total="301" page-length="100"/>, 4)),

test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>1</current-page>
    <total-pages>11</total-pages>
    <page-length>100</page-length>
    <previous-index/>
    <previous-page/>
    <next-index>101</next-index>
    <next-page>2</next-page>
    <showing>
      <start>1</start>
      <end>100</end>
      <total>1001</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="1" total="1001" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>2</current-page>
    <total-pages>11</total-pages>
    <page-length>100</page-length>
    <previous-index>1</previous-index>
    <previous-page>1</previous-page>
    <next-index>201</next-index>
    <next-page>3</next-page>
    <showing>
      <start>101</start>
      <end>200</end>
      <total>1001</total>
    </showing>
    <links>
      <link>2</link>
      <link>3</link>
      <link>4</link>
      <link>5</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="101" total="1001" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>3</current-page>
    <total-pages>11</total-pages>
    <page-length>100</page-length>
    <previous-index>101</previous-index>
    <previous-page>2</previous-page>
    <next-index>301</next-index>
    <next-page>4</next-page>
    <showing>
      <start>201</start>
      <end>300</end>
      <total>1001</total>
    </showing>
    <links>
      <link>1</link>
      <link>2</link>
      <link>3</link>
      <link>4</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="201" total="1001" page-length="100"/>, 4)),
test:assert-equal(
  <pagination xmlns="http://marklogic.com/roxy/pager-lib">
    <current-page>11</current-page>
    <total-pages>11</total-pages>
    <page-length>100</page-length>
    <previous-index>901</previous-index>
    <previous-page>10</previous-page>
    <next-index/>
    <next-page/>
    <showing>
      <start>1001</start>
      <end>1001</end>
      <total>1001</total>
    </showing>
    <links>
      <link>8</link>
      <link>9</link>
      <link>10</link>
      <link>11</link>
    </links>
  </pagination>,
  pager:paginate(<response xmlns="http://marklogic.com/appservices/search" start="1001" total="1001" page-length="100"/>, 4))