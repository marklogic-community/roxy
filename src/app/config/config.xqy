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

module namespace c = "http://marklogic.com/roxy/config";

import module namespace def = "http://marklogic.com/roxy/defaults" at "/roxy/config/defaults.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

(:
 : ***********************************************
 : Overrides for the Default Roxy control options
 :
 : See /roxy/config/defaults.xqy for the complete list of stuff that you can override.
 : Roxy will check this file (config.xqy) first. If no overrides are provided then it will use the defaults.
 :
 : Go to https://github.com/marklogic/roxy/wiki/Overriding-Roxy-Options for more details
 :
 : ***********************************************
 :)
declare variable $c:ROXY-OPTIONS :=
  <options>
    <layouts>
      <layout format="html">three-column</layout>
    </layouts>
  </options>;

(:
 : ***********************************************
 : Overrides for the Default Roxy scheme
 :
 : See /roxy/config/defaults.xqy for the default routes
 : Roxy will check this file (config.xqy) first. If no overrides are provided then it will use the defaults.
 :
 : Go to https://github.com/marklogic/roxy/wiki/Roxy-URL-Rewriting for more details
 :
 : ***********************************************
 :)
declare variable $c:ROXY-ROUTES :=
  <routes xmlns="http://marklogic.com/appservices/rest">
    <request uri="^/my/awesome/route" />
    {
      $def:ROXY-ROUTES/rest:request
    }
  </routes>;

(:
 : ***********************************************
 : A decent place to put your search config
 : and various other search options.
 : The examples below are used by the default
 : application.
 : ***********************************************
 :)
declare variable $c:DEFAULT-PAGE-LENGTH as xs:int := 10;

declare variable $c:SEARCH-OPTIONS :=
  <options xmlns="http://marklogic.com/appservices/search">
    <search-option>unfiltered</search-option>
    <term>
      <term-option>case-insensitive</term-option>
    </term>
    <constraint name="country" facet="true">
      <range type="xs:string" collation="http://marklogic.com/collation/codepoint">
        <element ns="urn:us:gov:ic:rmt" name="COUNTRY"/>
        <facet-option>limit=10</facet-option>
      </range>
    </constraint>
    <return-results>true</return-results>
    <return-query>true</return-query>
  </options>;

(:
 : Labels are used by faceting code to provide internationalization
 :)
declare variable $c:LABELS :=
  <labels xmlns="http://marklogic.com/xqutils/labels">
    <label key="facet1">
      <value xml:lang="en">Sample Facet</value>
    </label>
  </labels>;

declare variable $c:FACET-GROUPS :=
  <c:facet-groups>
    <c:group name="general">
      <c:facet-name>country</c:facet-name>
    </c:group>
  </c:facet-groups>;

(: The path to the "title" field of a document. Used to show result links. :)
declare variable $c:TITLE-PATH := "//*:SUBJECT";

(: Enable searching documents by date range. Requires a range index on an element. :)
declare variable $c:DATE-RANGE-ENABLED := fn:true();
declare variable $c:DATE-RANGE-ELEMENT-NAMES := (fn:QName("http://marklogic.com/edl", "dtr"));

(: Enables the time-series display on the application. **Requires DATE-RANGE-ENABLED to be true.** :)
declare variable $c:TIMESERIES-ENABLED := fn:true();
declare variable $c:TIMESERIES-DISPLAY-YEARS := 5; (: Number of years to display in timeseries graph. :)

(: GEOSPATIAL CONFIGURATION :)
declare variable $c:GEO-ENABLED := fn:true();
declare variable $c:GOOGLEMAPS-API-KEY := "AIzaSyDxtKbYPjJ8BrXTTNDgTlsT0mj4GAs5Na8";
declare variable $c:GEO-VALUES-LIMIT := 5000;
(: Geospatial Element Index :)
declare variable $c:GEO-ELEMENT-INDEX-NAMES := ((:fn:QName("http://marklogic.com/roxy", "GEO"):));
(: Geospatial Element Child Index :)
declare variable $c:GEO-ELEMENT-CHILD-INDEX-PARENT-NAMES := ((:fn:QName("http://marklogic.com/roxy", "GEO"):));
declare variable $c:GEO-ELEMENT-CHILD-INDEX-NAMES := ((:fn:QName("http://marklogic.com/roxy", "POINT"):));
(: Geospatial Element Pair Index :)
declare variable $c:GEO-ELEMENT-PAIR-INDEX-PARENT-NAMES := (fn:QName("urn:us:gov:ic:rmt:geo", "GEO"));
declare variable $c:GEO-ELEMENT-PAIR-INDEX-LAT-NAMES := (fn:QName("", "Latitude"));
declare variable $c:GEO-ELEMENT-PAIR-INDEX-LON-NAMES := (fn:QName("", "Longitude"));
(: Geospatial Attribute Pair Index :)
declare variable $c:GEO-ATTRIBUTE-PAIR-INDEX-PARENT-NAMES := (fn:QName("urn:us:gov:ic:rmt:geo", "GEO"));
declare variable $c:GEO-ATTRIBUTE-PAIR-INDEX-LAT-NAMES := (fn:QName("", "Latitude"));
declare variable $c:GEO-ATTRIBUTE-PAIR-INDEX-LON-NAMES := (fn:QName("", "Longitude"));
(: Geospatial Path Index :)
declare variable $c:GEO-PATH-INDEX-PATHS := ((: "/path/to/geo/node1", "/path/to/geo/node2" :));