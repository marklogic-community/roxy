<!-- Norm Walsh xproc book http://xprocbook.com/book/refentry-61.html //-->
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
    		xmlns:c="http://www.w3.org/ns/xproc-step"
    		xmlns:cx="http://xmlcalabash.com/ns/extensions"
                type="cx:recursive-directory-list"
                version="1.0">
  <p:output port="result"/>
  <p:option name="path" required="true"/>
  <p:option name="include-filter"/>
  <p:option name="exclude-filter"/>
  <p:option name="depth" select="-1"/>
  
  <p:choose>
    <p:when test="p:value-available('include-filter')
                  and p:value-available('exclude-filter')">
      <p:directory-list>
        <p:with-option name="path" select="$path"/>
        <p:with-option name="include-filter" select="$include-filter"/>
        <p:with-option name="exclude-filter" select="$exclude-filter"/>
      </p:directory-list>
    </p:when>
    
    <p:when test="p:value-available('include-filter')">
      <p:directory-list>
        <p:with-option name="path" select="$path"/>
        <p:with-option name="include-filter" select="$include-filter"/>
      </p:directory-list>
    </p:when>
    
    <p:when test="p:value-available('exclude-filter')">
      <p:directory-list>
        <p:with-option name="path" select="$path"/>
        <p:with-option name="exclude-filter" select="$exclude-filter"/>
      </p:directory-list>
    </p:when>
    
    <p:otherwise>
      <p:directory-list>
        <p:with-option name="path" select="$path"/>
      </p:directory-list>
    </p:otherwise>
  </p:choose>
  
  <p:viewport match="/c:directory/c:directory">
    <p:variable name="name" select="/*/@name"/>
    
    <p:choose>
      <p:when test="$depth != 0">
        <p:choose>
          <p:when test="p:value-available('include-filter')
                        and p:value-available('exclude-filter')">
            <cx:recursive-directory-list>
              <p:with-option name="path" select="concat($path,'/',$name)"/>
              <p:with-option name="include-filter" select="$include-filter"/>
              <p:with-option name="exclude-filter" select="$exclude-filter"/>
              <p:with-option name="depth" select="$depth - 1"/>
            </cx:recursive-directory-list>
          </p:when>
          
          <p:when test="p:value-available('include-filter')">
            <cx:recursive-directory-list>
              <p:with-option name="path" select="concat($path,'/',$name)"/>
              <p:with-option name="include-filter" select="$include-filter"/>
              <p:with-option name="depth" select="$depth - 1"/>
            </cx:recursive-directory-list>
          </p:when>
          
          <p:when test="p:value-available('exclude-filter')">
            <cx:recursive-directory-list>
              <p:with-option name="path" select="concat($path,'/',$name)"/>
              <p:with-option name="exclude-filter" select="$exclude-filter"/>
              <p:with-option name="depth" select="$depth - 1"/>
            </cx:recursive-directory-list>
          </p:when>
          
          <p:otherwise>
            <cx:recursive-directory-list>
              <p:with-option name="path" select="concat($path,'/',$name)"/>
              <p:with-option name="depth" select="$depth - 1"/>
            </cx:recursive-directory-list>
          </p:otherwise>
        </p:choose>
      </p:when>
      <p:otherwise>
    	<p:identity/>
      </p:otherwise>
    </p:choose>
  </p:viewport>
  
</p:declare-step>
