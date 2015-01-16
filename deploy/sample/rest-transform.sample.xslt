
<!--
REST API transforms managed by Roxy must follow these conventions:

1. Their filenames must reflect the name of the transform.

For example, an XSL transform named add-attr must be contained in a file named add-attr.xslt.

2. Must annotate the file with the transform parameters in an XML comment:

%roxy:params("uri=xs:string", "priority=xs:int")
-->

<!-- %roxy:params("uri=xs:string", "priority=xs:int") -->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:trns="http://marklogic.com/rest-api/transform/sample"
                xmlns:map="http://marklogic.com/xdmp/map">
    <xsl:param name="context" as="map:map"/>
    <xsl:param name="params" as="map:map"/>
    <xsl:template match="/*">
        <xsl:copy>
            <xsl:attribute
                    name='{{(map:get($params,"name"),"transformed")[1]}}'
                    select='(map:get($params,"value"),"UNDEFINED")[1]'/>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
