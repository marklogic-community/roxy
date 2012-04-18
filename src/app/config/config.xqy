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

(:
 : ***********************************************
 : Roxy control options
 : ***********************************************
 :)

(: the default controller that the URL http://server:port/ maps to :)
(: use appbuilder for an appbuilder clone :)
declare variable $DEFAULT-CONTROLLER := "appbuilder";

(: default layouts for various content types :)
(: use two-column for an appbuilder clone :)
declare variable $DEFAULT-LAYOUTS :=
  let $map := map:map()
  let $_ := map:put($map, "html", "two-column")
  return $map;

(: The default format to render results :)
declare variable $DEFAULT-FORMAT := "html";

(: Custom routes for URL mapping :)
declare variable $ROUTES := ();

(:
 : ***********************************************
 : A decent place to put your appservices search config
 : and various other search options
 : ***********************************************
 :)
declare variable $c:DEFAULT-PAGE-LENGTH as xs:int := 5;

declare variable $c:SEARCH-OPTIONS :=
  <options xmlns="http://marklogic.com/appservices/search">
    <search-option>unfiltered</search-option>
    <term>
      <term-option>case-insensitive</term-option>
     </term>
     <constraint name="facet1">
       <collection>
         <facet-option>limit=10</facet-option>
       </collection>
     </constraint>

    <return-results>true</return-results>
    <return-query>true</return-query>
  </options>;

(:
 : Labels are used by appbuilder faceting code to provide internationalization
 :)
declare variable $c:LABELS :=
  <labels xmlns="http://marklogic.com/xqutils/labels">
    <label key="facet1">
      <value xml:lang="en">Sample Facet</value>
    </label>
  </labels>;
