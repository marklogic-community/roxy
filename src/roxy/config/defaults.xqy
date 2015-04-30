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

module namespace d = "http://marklogic.com/roxy/defaults";

import module namespace config = "http://marklogic.com/roxy/config" at "/app/config/config.xqy";

declare namespace rest = "http://marklogic.com/appservices/rest";

(:
 : ***********************************************
 : Roxy control options
 : Don't edit these here. Instead override them in
 : /app/config/config.xqy
 : ***********************************************
 :)
declare variable $ROXY-OPTIONS :=
  <options>
    <!-- the default controller that the URL http://server:port/ maps to
         use appbuilder for an appbuilder clone -->
    <default-controller>appbuilder</default-controller>

    <!-- the default funciton that gets called when none is specified -->
    <default-function>main</default-function>

    <!-- the default format to use when rendering views -->
    <default-format>html</default-format>

    <!-- a mapping of default layouts to view formats -->
    <layouts>
      <layout format="html">two-column</layout>
    </layouts>
  </options>;


declare variable $ROXY-ROUTES :=
  (: The default Roxy routes :)
  let $default-controller :=
    (
      $config:ROXY-OPTIONS/*:default-controller,
      $ROXY-OPTIONS/*:default-controller
    )[1]
  let $default-function :=
    (
      $config:ROXY-OPTIONS/*:default-function,
      $ROXY-OPTIONS/*:default-function
    )[1]
  return
    <routes xmlns="http://marklogic.com/appservices/rest">
      <request uri="^/test/(js|img|css)/(.*)" />
      <request uri="^/test/default.xqy" />
      <request uri="^/test/(.*)" endpoint="/test/default.xqy">
        <uri-param name="func" default="{$default-function}">$1</uri-param>
      </request>
      <request uri="^/test$" redirect="/test/" />
      <request uri="^/(css|js|images)/(.*)" endpoint="/public/$1/$2"/>
      <request uri="^/favicon.ico$" endpoint="/public/favicon.ico"/>
      <request uri="^/v1/.+$"/>
      <request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/query-router.xqy">
        <uri-param name="controller" default="{$default-controller}">$1</uri-param>
        <uri-param name="func" default="{$default-function}">$2</uri-param>
        <uri-param name="format">$3</uri-param>
        <http method="GET"/>
        <http method="HEAD"/>
      </request>
      <request uri="^/([\w\d_\-]*)/?([\w\d_\-]*)\.?(\w*)/?$" endpoint="/roxy/update-router.xqy">
        <uri-param name="controller" default="{$default-controller}">$1</uri-param>
        <uri-param name="func" default="{$default-function}">$2</uri-param>
        <uri-param name="format">$3</uri-param>
        <http method="POST"/>
        <http method="PUT"/>
        <http method="DELETE"/>
      </request>
      <request uri="^.+$"/>
    </routes>;

(:
 : ***********************************************
 : A decent place to put your appservices search config
 : and various other search options
 : ***********************************************
 :)
declare variable $DEFAULT-PAGE-LENGTH as xs:int := 5;

declare variable $SEARCH-OPTIONS :=
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
declare variable $LABELS :=
  <labels xmlns="http://marklogic.com/xqutils/labels">
    <label key="facet1">
      <value xml:lang="en">Sample Facet</value>
    </label>
  </labels>;
