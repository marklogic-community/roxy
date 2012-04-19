<?xml version="1.0" encoding="UTF-8"?>
<!--
Copyright (c) 2011-2012 James Fuller

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
//-->
<p:declare-step 
    xmlns:c="http://www.w3.org/ns/xproc-step"
    xmlns:p="http://www.w3.org/ns/xproc"
    xmlns:cx="http://xmlcalabash.com/ns/extensions"
    xmlns:cxf="http://xmlcalabash.com/ns/extensions/fileutils"
    xmlns:pxp="http://exproc.org/proposed/steps"
    xmlns:depx="https://github.com/xquery/depx"
    type="depx:depx"
    name="depx"
    version="1.0"
    exclude-inline-prefixes="cx c p">

  <p:documentation>
    depx client written in xproc
  </p:documentation>

  <!--p:serialization port="result" method="text"/-->

  <p:input port="source"/>

  <p:import href="extension-library.xml"/>

  <!-- depx public repository  URL  //-->
  <p:option name="depxURL" select="'http://xquery.github.com/depx'"/>

  <!-- repository  URL  //-->
  <p:option name="downloadURL" select="concat($depxURL,'/downloads/')"/>

  <!-- repository  URL  //-->
  <p:option name="repoURL" select="concat($depxURL,'/packages/package.xml')"/>
  
  <!-- command //-->
  <p:option name="command" required="true"/>

  <!-- package name //-->
  <p:option name="package" select="''"/>  

  <!-- package version  //-->
  <p:option name="version" select="''"/>  

  <!-- application directory //-->
  <p:option name="app_dir"/>

  <!-- application lib relative path (to app_dir) //-->
  <p:option name="app_dir_lib" select="'/lib/'"/>

  <!-- output format //-->
  <p:option name="format" select="'text'"/>

  <!-- application depx uri //-->
  <p:variable name="app_dir_dep" select="concat($app_dir,'/depx.xml')"/>

  <!-- absolute application lib path //-->
  <p:variable name="lib_path" select="concat($app_dir,$app_dir_lib)"/>

  <p:variable name="notifyURI" select="concat('http://depx.org/data/download/add?name=',$package,'&amp;version=',$version)"/>

  <!-- full package name //-->
  <p:variable name="packageName" select="concat($package,'-',$version,'.zip')"/>

  <p:variable name="dirName1" select="concat(tokenize($package,'\.')[last()],'-',$version)"/>

  <p:variable name="dirName" select="concat(tokenize($package,'\.')[last()],'-',$version,'.zip')"/>

  <!-- file name of clientside depx bom  //-->
  <p:variable name="depx" select="concat($lib_path,'depx.xml')"/>  

  <!-- define steps //-->
  <p:declare-step type="depx:notify-depx">
    <!-- notify depx.org of download and installation //-->
    <p:option name="notifyDownload" select="'true'" />
    <p:option name="notifyURI"/>

    <p:in-scope-names name="vars"/>
    <p:template name="downloadtemplate">
      <p:input port="source"><p:empty/></p:input>
      <p:input port="template">
        <p:inline>
          <c:request status-only="true" detailed="true" method="GET" auth-method="digest" username="depx-beta" password="urock" href="{$notifyURI}"/>
        </p:inline>
      </p:input>
      <p:input port="parameters">
        <p:pipe step="vars" port="result"/>
      </p:input>
    </p:template>

    <p:choose>
      <p:when test="$notifyDownload eq 'true'">
        <p:http-request/>
      </p:when>
      <p:otherwise>
      <p:identity/>
      </p:otherwise>
    </p:choose>
      <p:sink/>

  </p:declare-step>
  <p:declare-step type="depx:install-zip">
    <p:option name="package"/>
    <p:option name="version"/>
    <p:option name="app_dir_dep"/>
    <p:option name="lib_path"/>
    <p:option name="downloadURL"/>
    <p:variable name="packageName" select="concat($package,'-',$version,'.zip')"/>
    <p:in-scope-names name="vars"/>

    <cx:unzip>
      <p:with-option name="href" select="concat($downloadURL,$packageName)"/>
    </cx:unzip>

    <p:for-each>
      <p:iteration-source select="//c:file"/>
      <p:variable name="file" select="c:file/@name"/>

      <cx:unzip content-type="*">
        <p:with-option name="href" select="concat($downloadURL,$packageName)"/>
        <p:with-option name="file" select="$file"/>
      </cx:unzip>
      
      <p:add-attribute match="/c:data" 
                       attribute-name="encoding" 
                       attribute-value="base64"/>

      <p:store cx:decode="true">
        <p:with-option name="href" select="concat($lib_path,$file)"/>
      </p:store>
    </p:for-each>
  </p:declare-step>

  <p:in-scope-names name="vars"/>

  <p:choose name="read-depx">
    <!-- load existing depx.xml //-->
    <p:when test="doc-available($depx)">   
      <p:output port="result"/>
      <p:load>
        <p:with-option name="href" select="$depx"/>
      </p:load>
    </p:when>
    <!-- load new (empty) depx.xml //-->
    <p:otherwise>
      <p:output port="result"/>
      <p:template>
        <p:input port="template">
          <p:inline>
            <depx:depx ts="{current-dateTime()}"/>
          </p:inline>
        </p:input>
        <p:input port="source">
          <p:pipe step="depx" port="source"/>
        </p:input>
        <p:input port="parameters">
          <p:pipe step="vars" port="result"/>
        </p:input>
      </p:template>
    </p:otherwise>
  </p:choose>

  <p:choose name="process-command">
    <!-- package is already installed //-->
    <p:when test="$command eq 'install' and
                  /depx:depx/depx:package/@name = $package">
      <p:output port="result"/>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:when>

    <!-- package is already removed //-->
    <p:when test="$command eq 'remove' and
                  /depx:depx/depx:package/@name != $package">
      <p:output port="result"/>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:when>

    <!-- generate //-->
    <p:when test="$command eq 'generate'">
      <p:output port="result"/>
      <p:xslt name="generate-app">
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
        <p:input port="stylesheet">
          <p:inline>
            <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                            xmlns="https://github.com/xquery/depx"
                            xmlns:depx="https://github.com/xquery/depx"
                            version="1.0"
                            exclude-result-prefixes="depx pxp cxf">
              <xsl:output method="xml" indent="yes"/>
              <xsl:param name="package"/>
              <xsl:param name="version"/>
              <xsl:template match="/">
                <package 
                    name="{$package}"
                    version="{$version}">
                  <title>Title used at depx.org</title>
                  <desc>Description of your package at depx.org</desc>
                  <license type="GNU-LGPL|Other">
                    <uri>required</uri>
                  </license>
                  <repo type="git|svn">
                    <uri>required</uri>
                  </repo>
                  <author id="depx profile id | github profile id">your name</author>
                  <website>package related website</website>
                  <!-- use one of the following entry points, depending on your package //-->
                  <xquery version="">
                    <prefix></prefix>
                    <namespace></namespace>
                    <uri></uri>
                  </xquery>
                  <xslt>
                    <prefix></prefix>
                    <namespace></namespace>
                    <uri></uri>
                  </xslt>
                  <xproc>
                    <prefix></prefix>
                    <namespace></namespace>
                    <uri></uri>
                  </xproc>    
                  <schema>
                    <prefix></prefix>
                    <namespace></namespace>
                    <uri></uri>
                  </schema>      
                  <css>
                    <uri></uri>
                  </css>  
                  <js>
                    <uri></uri>
                  </js>          
                  <app>
                    <uri></uri>
                  </app>  
                  <!-- dependences //-->
                  <xsl:apply-templates select="//depx:package"/>
                </package>
              </xsl:template>
              <xsl:template match="depx:package">
                <dep name="{@name}" version="{@version}"/>
              </xsl:template>
            </xsl:stylesheet>
          </p:inline>
        </p:input>
        <p:input port="parameters">
          <p:pipe step="vars" port="result"/>
        </p:input>   
      </p:xslt>
      <p:store indent="true">
        <p:with-option name="href" select="$app_dir_dep"/>
      </p:store>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:when>

    <!-- (re)install all packages defined in depx.xml //-->
    <p:when test="$command eq 'refresh'">
      <p:output port="result"/>
      <p:for-each>
        <p:iteration-source select="/depx:depx/depx:package">
          <p:pipe step="read-depx" port="result"/>
        </p:iteration-source>

        <depx:install-zip>
          <p:with-option name="package" select="/depx:package/@name"/>
          <p:with-option name="version" select="/depx:package/@version"/>
          <p:with-option name="app_dir_dep" select="$app_dir_dep"/>
          <p:with-option name="lib_path" select="$lib_path"/>
          <p:with-option name="downloadURL" select="$downloadURL"/>
        </depx:install-zip>
      </p:for-each>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:when>

    <!-- remove all packages //-->
    <p:when test="$command eq 'remove' and $package eq 'all'">
      <p:output port="result"/>
      <p:for-each>
        <p:iteration-source select="/depx:depx/depx:package">
          <p:pipe step="read-depx" port="result"/>
        </p:iteration-source>

        <p:variable name="pname" select="tokenize(/depx:package/@name,'\.')[last()]"/>
        <p:variable name="pversion" select="/depx:package/@version"/>
        <p:variable name="package-name" select="concat($pname,'-',$pversion)"/>

        <cxf:delete recursive="true">
          <p:with-option name="href"
                         select="concat('file://',$lib_path,$package-name)"/>
        </cxf:delete>
      </p:for-each>
      <p:identity>
        <p:input port="source">
          <p:inline><depx:depx/></p:inline>
        </p:input>
      </p:identity>
    </p:when>

    <!-- install package at lib/depx.xml //-->
    <p:when test="$command eq 'install' and $version ne ''">
      <p:output port="result"/>

      <depx:notify-depx>
        <p:with-option name="notifyURI" select="$notifyURI"/>
      </depx:notify-depx>

      <p:filter name="get-package">
        <p:input port="source" >
          <p:document href="http://xquery.github.com/depx/packages/package.xml"/>
        </p:input>
        <p:with-option name="select"
                       select="concat('/depx:depx/depx:package[@name eq
                               &quot;',$package,'&quot;][@version eq &quot;',$version,'&quot;]')"/>
      </p:filter>

      <!-- install package dependencies //-->
      <p:for-each>
        <p:iteration-source select="/depx:package/depx:dep"/>
        
        <p:variable name="pname" select="depx:dep/@name"/>
        <p:variable name="pversion" select="depx:dep/@version"/>

        <depx:depx>
          <p:with-option name="package" select="$pname"/>
          <p:with-option name="version" select="$pversion"/>
          <p:with-option name="command" select="'install'"/>
          <p:with-option name="app_dir" select="$app_dir"/>
        </depx:depx>

      </p:for-each>

      <depx:install-zip>
        <p:with-option name="package" select="$package"/>
        <p:with-option name="version" select="$version"/>
        <p:with-option name="app_dir_dep" select="$app_dir_dep"/>
        <p:with-option name="lib_path" select="$lib_path"/>
        <p:with-option name="downloadURL" select="$downloadURL"/>
      </depx:install-zip>

      <p:insert match="depx:depx" position="last-child">
        <p:input port="source">
          <p:pipe port="result" step="read-depx"/>
        </p:input>
        <p:input port="insertion">
          <p:pipe port="result" step="get-package"/>
        </p:input>
      </p:insert>      

    </p:when> 

    <!-- install LATEST version of package //-->
    <p:when test="$command eq 'install' and $version eq ''">
      <p:output port="result"/>


      <depx:notify-depx>
        <p:with-option name="notifyURI" select="$notifyURI"/>
      </depx:notify-depx>

      <p:filter name="get-package">
        <p:input port="source" >
          <p:document href="http://xquery.github.com/depx/packages/package.xml"/>
        </p:input>
        <p:with-option name="select"
                       select="concat('/depx:depx/depx:package[@name eq
                               &quot;',$package,'&quot;][1]')"/>
      </p:filter>

      <!-- install package dependencies //-->
      <p:for-each>
        <p:iteration-source select="/depx:package/depx:dep"/>
        
        <p:variable name="pname" select="depx:dep/@name"/>
        <p:variable name="pversion" select="depx:dep/@version"/>

        <depx:depx>
          <p:with-option name="package" select="$pname"/>
          <p:with-option name="version" select="$pversion"/>
          <p:with-option name="command" select="'install'"/>
          <p:with-option name="app_dir" select="$app_dir"/>
        </depx:depx>

      </p:for-each>

      <depx:install-zip>
        <p:with-option name="package" select="$package"/>
        <p:with-option name="version" select="$version"/>
        <p:with-option name="app_dir_dep" select="$app_dir_dep"/>
        <p:with-option name="lib_path" select="$lib_path"/>
        <p:with-option name="downloadURL" select="$downloadURL"/>
      </depx:install-zip>

      <p:insert match="depx:depx" position="last-child">
        <p:input port="source">
          <p:pipe port="result" step="read-depx"/>
        </p:input>
        <p:input port="insertion">
          <p:pipe port="result" step="get-package"/>
        </p:input>
      </p:insert>      

    </p:when> 

    <!-- remove existing package from client depx.xml //-->
    <p:when test="$command eq 'remove' and $version ne ''">
      <p:output port="result"/>

      <cxf:delete recursive="true">
        <p:with-option name="href"
                       select="concat('file://',$lib_path,$dirName1)"/>
      </cxf:delete>

      <p:delete>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
        <p:with-option name="match" select="concat('/depx:depx/depx:package[@name eq &quot;',$package,'&quot;][@version eq &quot;',$version,'&quot;]')"/> 
      </p:delete>

    </p:when> 

    <!-- list out installed packages from client depx.xml //-->
    <p:when test="command eq 'list'">
      <p:output port="result"/>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:when>

    <!-- list out all repo packages from repoURL //-->
    <p:otherwise>
      <p:output port="result"/>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity>
    </p:otherwise>
  </p:choose>

  <p:store>
    <p:with-option name="href" select="$depx"/>
  </p:store>


  <!-- run pipeline manually in emacs with m-x compile //-->
  <p:documentation>
    (:
    -- Local Variables:
    -- compile-command: "/usr/local/bin/calabash depx.xpl command=install package=xquery.1.functx version=1.0 app_dir=file:///Users/jfuller/depx-test"
    -- End:
    :)
  </p:documentation>

</p:declare-step>


