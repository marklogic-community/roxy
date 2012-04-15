<p:library xmlns:p="http://www.w3.org/ns/xproc"
	   xmlns:cx="http://xmlcalabash.com/ns/extensions"
	   xmlns:ml="http://xmlcalabash.com/ns/extensions/marklogic"
	   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
           version="1.0">

<p:documentation xmlns="http://www.w3.org/1999/xhtml">
<div>
<h1>XML Calabash Extension Library</h1>
<h2>Version 1.0</h2>
<p>The steps defined in this library are implemented in
<a href="http://xmlcalabash.com/">XML Calabash</a>.
</p>
</div>
</p:documentation>

<p:declare-step type="cx:metadata-extractor">
  <p:output port="result"/>
  <p:option name="href" required="true"/>
</p:declare-step>

<p:declare-step type="cx:unzip">
  <p:output port="result"/>
  <p:option name="href" required="true" cx:type="xsd:anyURI"/>
  <p:option name="file"/>
  <p:option name="content-type"/>
</p:declare-step>

<p:declare-step type="cx:zip">
  <p:input port="source" sequence="true" primary="true"/>
  <p:input port="manifest"/>
  <p:output port="result"/>
  <p:option name="href" required="true" cx:type="xsd:anyURI"/>
  <p:option name="compression-method" cx:type="stored|deflated"/>
  <p:option name="compression-level"
	    cx:type="smallest|fastest|default|huffman|none"/>
  <p:option name="command" select="'update'" cx:type="update|freshen|create|delete"/>

  <p:option name="byte-order-mark" cx:type="xsd:boolean"/>
  <p:option name="cdata-section-elements" select="''" cx:type="ListOfQNames"/>
  <p:option name="doctype-public" cx:type="xsd:string"/>
  <p:option name="doctype-system" cx:type="xsd:anyURI"/>
  <p:option name="encoding" cx:type="xsd:string"/>
  <p:option name="escape-uri-attributes" select="'false'" cx:type="xsd:boolean"/>
  <p:option name="include-content-type" select="'true'" cx:type="xsd:boolean"/>
  <p:option name="indent" select="'false'" cx:type="xsd:boolean"/>
  <p:option name="media-type" cx:type="xsd:string"/>
  <p:option name="method" select="'xml'" cx:type="xsd:QName"/>
  <p:option name="normalization-form" select="'none'" cx:type="NormalizationForm"/>
  <p:option name="omit-xml-declaration" select="'true'" cx:type="xsd:boolean"/>
  <p:option name="standalone" select="'omit'" cx:type="true|false|omit"/>
  <p:option name="undeclare-prefixes" cx:type="xsd:boolean"/>
  <p:option name="version" select="'1.0'" cx:type="xsd:string"/>
</p:declare-step>

<p:declare-step type="cx:delta-xml">
  <p:input port="source"/>
  <p:input port="alternate"/>
  <p:input port="dxp"/>
  <p:output port="result"/>
</p:declare-step>

<p:declare-step type="cx:message">
  <p:input port="source"/>
  <p:output port="result"/>
  <p:option name="message" required="true"/>
</p:declare-step>

<p:declare-step type="cx:collection-manager">
  <p:input port="source" sequence="true"/>
  <p:output port="result" sequence="true" primary="false"/>
  <p:option name="href" required="true" cx:type="xsd:anyURI"/>
</p:declare-step>

<p:declare-step type="ml:adhoc-query">
  <p:input port="source" sequence="true" primary="true"/>
  <p:input port="parameters" kind="parameter"/>
  <p:output port="result" sequence="true"/>
  <p:option name="host"/>
  <p:option name="port" cx:type="xsd:integer"/>
  <p:option name="user"/>
  <p:option name="password"/>
  <p:option name="content-base"/>
  <p:option name="wrapper" cx:type="xsd:QName"/>
</p:declare-step>

<p:declare-step type="ml:invoke-module">
  <p:input port="parameters" kind="parameter"/>
  <p:output port="result" sequence="true"/>
  <p:option name="module" required="true"/>
  <p:option name="host"/>
  <p:option name="port" cx:type="xsd:integer"/>
  <p:option name="user"/>
  <p:option name="password"/>
  <p:option name="content-base"/>
  <p:option name="wrapper" cx:type="xsd:QName"/>
</p:declare-step>

<p:declare-step type="ml:insert-document">
  <p:input port="source"/>
  <p:output port="result" primary="false"/>
  <p:option name="host"/>
  <p:option name="port" cx:type="xsd:integer"/>
  <p:option name="user"/>
  <p:option name="password"/>
  <p:option name="content-base"/>
  <p:option name="uri" required="true"/>
  <p:option name="buffer-size" cx:type="xsd:integer"/>
  <p:option name="collections"/>
  <p:option name="format" cx:type="xml|text|binary"/>
  <p:option name="language"/>
  <p:option name="locale"/>
</p:declare-step>

</p:library>
