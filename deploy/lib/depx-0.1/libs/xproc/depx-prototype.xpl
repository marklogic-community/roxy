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

    @option command = install | remove | refresh 
    @option package= package name | all 
    @option repoURL= url of package.xml

    @returns
  </p:documentation>

  <!-- serialisation output from command //--> <!-- be nice if we
  could set this dynamically //-->
  <p:serialization port="result" method="text"/>

  <p:input port="source"/>
  <p:output port="result">
    <p:pipe step="generate-home" port="result"/>
  </p:output>

  <p:import href="extension-library.xml"/>

  <!-- depx public repository  URL  //-->
  <p:option name="depxURL" select="'http://xquery.github.com/depx'"/>

  <!-- repository  URL  //-->
  <p:option name="downloadURL" select="concat($depxURL,'/downloads/')"/>

  <!-- repository  URL  //-->
  <p:option name="repoURL" select="concat($depxURL,'/packages/package.xml')"/>
  
  <!-- location of wget //-->
  <p:option name="wget" select="'/usr/local/bin/wget'"/>

  <!-- location of rm //-->
  <p:option name="rm" select="'/bin/rm'"/>

  <!-- location of unzip //-->
  <p:option name="unzip" select="'/usr/bin/unzip'"/>

  <!-- command //-->
  <p:option name="command" required="true"/>

  <!-- notify depx of installation //-->
  <p:option name="notifyDownload" select="'true'" />

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

    <!-- package is already installed at client depx.xml, or generate
         command so do nothing  //-->
    <p:when test="$command eq 'install' and
                  /depx:depx/depx:package/@name = $package or $command
                  eq 'generate'">
      <p:output port="result"/>
      <p:identity/>
    </p:when>

    <!-- (re)install all packages defined in depx.xml //-->
    <p:when test="($command eq 'refresh' and $package eq 'all') or
                  ($command eq 'install' and $package eq 'all')">
      <p:output port="result"/>
      
      <p:for-each>
        <p:iteration-source select="/depx:depx/depx:package">
          <p:pipe step="read-depx" port="result"/>
        </p:iteration-source>

        <p:variable name="pname" select="/depx:package/@name"/>
        <p:variable name="pversion" select="/depx:package/@version"/>

        <p:variable name="package-name" select="concat($pname,'-',$pversion,'.zip')"/>

          <p:exec command="/usr/local/bin/wget" result-is-xml="false">
        <p:with-option name="args"
                       select="concat($downloadURL,$package-name,' -O ',$lib_path,$package-name)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
      <p:exec command="/usr/bin/unzip" result-is-xml="false">
        <p:with-option name="args"
                       select="concat($lib_path,$package-name,' -d ',$lib_path)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$rm"/>

        <p:with-option name="args"
                       select="concat($lib_path,$package-name)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
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

      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$rm"/>

        <p:with-option name="args"
                       select="concat('-R -f ',$lib_path,$package-name)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>

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


      <p:template name="downloadtemplate">
        <p:input port="template">
          <p:inline>
            <c:request method="GET" href="{$notifyURI}"
                       auth-method="digest" username="depx-beta" password="depx1"/>
          </p:inline>
        </p:input>
        <p:input port="source"/>
        <p:input port="parameters">
          <p:pipe step="vars" port="result"/>
        </p:input>
      </p:template>
      <p:http-request/>

      <p:filter name="get-package">
        <p:input port="source" >
          <p:document href="http://xquery.github.com/depx/packages/package.xml"/>
        </p:input>
        <p:with-option name="select"
                       select="concat('/depx:depx/depx:package[@name eq
                               &quot;',$package,'&quot;][@version eq &quot;',$version,'&quot;]')"/>
      </p:filter>

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

      <p:insert match="depx:depx" position="last-child">
        <p:input port="source">
          <p:pipe port="result" step="read-depx"/>
        </p:input>
        <p:input port="insertion">
          <p:pipe port="result" step="get-package"/>
        </p:input>
      </p:insert>      

    </p:when> 

    <!-- install latest version of package at client depx.xml //-->
    <p:when test="$command eq 'install' and $version eq ''">
      <p:output port="result"/>

      <p:filter name="get-package">
        <p:input port="source" >
          <p:document href="http://xquery.github.com/depx/packages/package.xml"/>
        </p:input>
        <p:with-option name="select"
                       select="concat('/depx:depx/depx:package[@name eq
                               &quot;',$package,'&quot;][1]')"/>
      </p:filter>

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
      <p:delete>
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

  <!-- store application's changes to depx.xml //-->
  <p:store>
    <p:with-option name="href" select="$depx"/>
  </p:store>

  <!-- install/remove zip package //-->
  <p:choose>
    <p:when test="$command eq 'generate'">
      <p:xslt name="generate-app">
        <p:input port="source">
          <p:pipe step="process-command" port="result"/>
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


    </p:when>
    <p:when test="$command eq 'remove'">
      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$rm"/>
        <p:with-option name="args"
                       select="concat('-R -f ',$lib_path,$dirName1)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
  <p:sink/> 

    </p:when>
    <p:when test="$command eq 'install'">
      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$wget"/>
        <p:with-option name="args"
                       select="concat($downloadURL,$packageName,' -O ',$lib_path,$packageName)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$unzip"/>
        <p:with-option name="args"
                       select="concat($lib_path,$packageName,' -d ',$lib_path)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
      <p:exec result-is-xml="false">
        <p:with-option name="command" select="$rm"/>
        <p:with-option name="args"
                       select="concat($lib_path,$packageName)"/>
        <p:input port="source">
          <p:empty/>
        </p:input>
      </p:exec>
      <p:sink/> 

    </p:when>
    <p:otherwise>
      <p:identity>
        <p:input port="source">
          <p:pipe step="read-depx" port="result"/>
        </p:input>
      </p:identity> 
      <p:sink/> 

    </p:otherwise>
  </p:choose>



  <!-- generate status (TEMP) //-->
  <p:xslt name="generate-home">
    <p:input port="source">
      <p:pipe step="process-command" port="result"/>
    </p:input>
    <p:input port="stylesheet">
      <p:inline>
        <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                        xmlns:depx="https://github.com/xquery/depx"
                        xmlns="http://www.w3.org/1999/xhtml"
                        version="2.0">
          <xsl:output method="text" encoding="UTF8" omit-xml-declaration="yes" indent="no"/>

          <xsl:param name="command"/>
          <xsl:param name="app_dir"/>
          <xsl:param name="repoURL"/>
          <xsl:param name="downloadURL"/>

          <xsl:param name="lib_path"/>
          <xsl:param name="packageName"/>
          <xsl:param name="format"/>

          <xsl:template match="depx:depx">
<depx> 
              <xsl:choose>
                <xsl:when test="$format eq 'xml'">
                  <command><xsl:value-of select="$command"/></command>
                  <repo><xsl:value-of select="$repoURL"/></repo>
                  <from><xsl:value-of select="concat($downloadURL,$packageName)"/></from>
                  <to><xsl:value-of select="$lib_path"/><xsl:value-of select="$packageName"/></to>
                  <xsl:apply-templates select="depx:package" mode="xml"/>
                </xsl:when>
                <xsl:otherwise>      
download from: <xsl:value-of select="$downloadURL"/>
   install to: <xsl:value-of select="$lib_path"/>

-------------------------
installed packages
-------------------------
                  <xsl:apply-templates select="depx:package" mode="text"/>
                </xsl:otherwise>
              </xsl:choose>
                </depx>
              </xsl:template>

              <xsl:template match="depx:package" mode="text">
name: <xsl:value-of select="@name"/>
version: <xsl:value-of select="@version"/>
ns:<xsl:value-of select="@ns"/>
file: <xsl:value-of select="*/depx:file[1]"/>
author: <xsl:value-of select="depx:author"/>                
website: <xsl:value-of select="depx:website"/>

-------------------------
              </xsl:template>

              <xsl:template match="depx:package" mode="xml">
                <name><xsl:value-of select="@name"/></name>
                <version><xsl:value-of select="@version"/></version>
                <ns><xsl:value-of select="@ns"/></ns>
                <file><xsl:value-of select="*/depx:file[1]"/></file>
                <author> <xsl:value-of select="depx:author"/></author>        
                <website> <xsl:value-of select="depx:website"/></website>
              </xsl:template>
            </xsl:stylesheet>
          </p:inline>
        </p:input>
        <p:input port="parameters">
          <p:pipe step="vars" port="result"/>
        </p:input>   
      </p:xslt>


      <!-- run pipeline manually in emacs with m-x compile //-->
      <p:documentation>
        (:
        -- Local Variables:
        -- compile-command: "/usr/local/bin/calabash depx.xpl command=install package=xquery.1.functx version=1.0 app_dir=/Users/jfuller/depx-test"
        -- End:
        :)
      </p:documentation>

    </p:declare-step>


