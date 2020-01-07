<?xml version='1.0'?>
<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>
<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  exclude-result-prefixes="marc str">
	<xsl:template name="datafield">
		<xsl:param name="tag"/>
		<xsl:param name="ind1"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="ind2"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subfields"/>
		<xsl:element name="datafield">
			<xsl:attribute name="tag">
				<xsl:value-of select="$tag"/>
			</xsl:attribute>
			<xsl:attribute name="ind1">
				<xsl:value-of select="$ind1"/>
			</xsl:attribute>
			<xsl:attribute name="ind2">
				<xsl:value-of select="$ind2"/>
			</xsl:attribute>
			<xsl:copy-of select="$subfields"/>
		</xsl:element>
	</xsl:template>

	<xsl:template name="subfieldSelect">
		<xsl:param name="codes"/>
		<xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subdivCodes"/>
		<xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
        <xsl:param name="urlencode"/>
		<xsl:variable name="str">
			<xsl:for-each select="marc:subfield">
				<xsl:if test="contains($codes, @code)">
                    <xsl:if test="contains($subdivCodes, @code)">
                        <xsl:value-of select="$subdivDelimiter"/>
                    </xsl:if>
					<xsl:value-of select="$prefix"/><xsl:value-of select="text()"/><xsl:value-of select="$suffix"/><xsl:value-of select="$delimeter"/>
				</xsl:if>
			</xsl:for-each>
		</xsl:variable>
        <xsl:choose>
            <xsl:when test="$urlencode=1">
                <xsl:value-of select="str:encode-uri(substring($str,1,string-length($str)-string-length($delimeter)), true())"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="substring($str,1,string-length($str)-string-length($delimeter))"/>
            </xsl:otherwise>
        </xsl:choose>
	</xsl:template>

    <xsl:template name="subfieldSelectSpan">
        <xsl:param name="codes"/>
        <xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
        <xsl:param name="subdivCodes"/>
        <xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($codes, @code)">
                    <span>
                        <xsl:attribute name="class"><xsl:value-of select="@code"/></xsl:attribute>
                        <xsl:if test="contains($subdivCodes, @code)">
                            <xsl:value-of select="$subdivDelimiter"/>
                        </xsl:if>
                        <xsl:value-of select="$prefix"/><xsl:value-of select="text()"/><xsl:value-of select="$suffix"/><xsl:if test="position()!=last()"><xsl:value-of select="$delimeter"/></xsl:if>
                    </span>
                </xsl:if>
            </xsl:for-each>
    </xsl:template>

	<xsl:template name="buildSpaces">
		<xsl:param name="spaces"/>
		<xsl:param name="char"><xsl:text> </xsl:text></xsl:param>
		<xsl:if test="$spaces>0">
			<xsl:value-of select="$char"/>
			<xsl:call-template name="buildSpaces">
				<xsl:with-param name="spaces" select="$spaces - 1"/>
				<xsl:with-param name="char" select="$char"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

  <xsl:template name="buildBiblioDefaultViewURL">
    <xsl:param name="BiblioDefaultView"/>
    <xsl:choose>
        <xsl:when test="$BiblioDefaultView='normal'">
            <xsl:text>/cgi-bin/koha/opac-detail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:when test="$BiblioDefaultView='isbd'">
            <xsl:text>/cgi-bin/koha/opac-ISBDdetail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:when test="$BiblioDefaultView='marc'">
            <xsl:text>/cgi-bin/koha/opac-MARCdetail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:otherwise>
            <xsl:text>/cgi-bin/koha/opac-detail.pl?biblionumber=</xsl:text>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

	<xsl:template name="chopPunctuation">
		<xsl:param name="chopString"/>
		<xsl:variable name="length" select="string-length($chopString)"/>
		<xsl:choose>
			<xsl:when test="$length=0"/>
			<xsl:when test="contains('.:,;/ ', substring($chopString,$length,1))">
				<xsl:call-template name="chopPunctuation">
					<xsl:with-param name="chopString" select="substring($chopString,1,$length - 1)"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="not($chopString)"/>
			<xsl:otherwise><xsl:value-of select="$chopString"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- Function extractControlNumber is used to extract the control number (record number) from MARC tags 773/80/85 [etc.] subfield $w.
	     Parameter: control number string.
	     Assumes LOC convention: (OrgCode)recordNumber.
	     If OrgCode is not present, return full string.
	     Additionally, handle various brackets/parentheses. Chop leading and trailing spaces.
         Returns the value URI-encoded.
	-->
	<xsl:template name="extractControlNumber">
	    <xsl:param name="subfieldW"/>
	    <xsl:variable name="tranW" select="translate($subfieldW,']})&gt;','))))')"/>
	    <xsl:choose>
	      <xsl:when test="contains($tranW,')')">
	        <xsl:value-of select="str:encode-uri(normalize-space(translate(substring-after($tranW,')'),'[]{}()&lt;&gt;','')), true())"/>
	      </xsl:when>
	      <xsl:otherwise>
	        <xsl:value-of select="str:encode-uri(normalize-space($subfieldW), true())"/>
	      </xsl:otherwise>
	    </xsl:choose>
	</xsl:template>

    <!-- Function m880Select:  Display Alternate Graphic Representation (MARC 880) for selected latin "base"tags
        - should be called immediately before the corresonding latin tags are processed
        - tags in right-to-left languages are displayed floating right
        * Parameter:
           + basetags: display these tags if found in linkage section ( subfield 6) of tag 880
           + codes: display these subfields codes
        * Options:
            - class: wrap output in <span class="$class">...</span>
            - label: prefix each(!) tag with label $label
            - bibno: link to biblionumber $bibno
            - index: build a search link using index $index with subfield $a as key; if subfield $9 is present use index 'an' with key $9 instead.
         * Limitations:
            - displays every field on a separate line (to switch between rtl and ltr)
         * Pitfalls:
           (!) output might be empty
    -->
    <xsl:template name="m880Select">
         <xsl:param name="basetags"/> <!-- e.g.  100,700,110,710 -->
        <xsl:param name="codes"/> <!-- e.g. abc  -->
        <xsl:param name="class"/> <!-- e.g. results_summary -->
        <xsl:param name="label"/> <!-- e.g.  Edition -->
        <xsl:param name="bibno"/>
        <xsl:param name="index"/> <!-- e.g.  au -->

        <xsl:for-each select="marc:datafield[@tag=880]">
            <xsl:variable name="code6" select="marc:subfield[@code=6]"/>
            <xsl:if test="contains(string($basetags), substring($code6,1,3))">
                <span>
                    <xsl:choose>
                    <xsl:when test="boolean($class) and substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                        <xsl:attribute name="dir">rtl</xsl:attribute>
                    </xsl:when>
                     <xsl:when test="boolean($class)">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
                        <xsl:attribute name="style">display:block; </xsl:attribute>
                    </xsl:when>
                     <xsl:when test="substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                    </xsl:when>
                    </xsl:choose>
                    <xsl:if test="boolean($label)">
                        <span class="label">
                            <xsl:value-of select="$label"/>
                        </span>
                    </xsl:if>
                    <xsl:variable name="str">
                        <xsl:for-each select="marc:subfield">
                            <xsl:if test="contains($codes, @code)">
                                <xsl:value-of select="text()"/>
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:if test="string-length($str) &gt; 0">
                        <xsl:choose>
                            <xsl:when test="boolean($bibno)">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-detail.pl?biblionumber=<xsl:value-of  select="str:encode-uri($bibno, true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                           <xsl:when test="boolean($index) and boolean(marc:subfield[@code=9])">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=an:<xsl:value-of  select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                            <xsl:when test="boolean($index)">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="str:encode-uri($index, true())"/>:<xsl:value-of select="str:encode-uri(marc:subfield[@code='a'], true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$str"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </span>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="showRDAtag264">
        <!-- Function showRDAtag264 shows selected information from tag 264
         on the Publisher line (used by OPAC Detail and Results)
         Depending on how many tags you have, we will pick by preference
         Publisher-latest or Publisher or 'Other'-latest or 'Other'
         The preferred tag is saved in the fav variable and passed to a
         helper named-template -->
        <!-- Amended  to show all 264 fields (filtered by ind1=3 if ind1=3 is present in the record)  -->
        <xsl:param name="show_url"/>
        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=264 and @ind1=3]">
                <xsl:for-each select="marc:datafield[@tag=264 and @ind1=3]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="marc:datafield[@tag=264]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="showRDAtag264helper">
        <xsl:param name="field"/>
        <xsl:param name="url"/>
        <xsl:variable name="ind2" select="$field/@ind2"/>
        <span class="results_summary rda264">
            <xsl:choose>
                <xsl:when test="$ind2='0'">
                    <span class="label">Producer: </span>
                </xsl:when>
                <xsl:when test="$ind2='1'">
                    <span class="label">Publisher: </span>
                </xsl:when>
                <xsl:when test="$ind2='2'">
                    <span class="label">Distributor: </span>
                </xsl:when>
                <xsl:when test="$ind2='3'">
                    <span class="label">Manufacturer: </span>
                </xsl:when>
                <xsl:when test="$ind2='4'">
                    <span class="label">Copyright date: </span>
                </xsl:when>
            </xsl:choose>

            <xsl:if test="$field/marc:subfield[@code='a']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">a</xsl:with-param>
                </xsl:call-template>
            </xsl:if>
            <xsl:text> </xsl:text>

            <xsl:choose>
                <xsl:when test="$url='1'">
                    <xsl:if test="$field/marc:subfield[@code='b']">
                         <a>
                         <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=Provider:<xsl:value-of select="str:encode-uri($field/marc:subfield[@code='b'], true())"/>"</xsl:attribute>
                         <xsl:call-template name="subfieldSelect">
                             <xsl:with-param name="codes">b</xsl:with-param>
                         </xsl:call-template>
                         </a>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="$field/marc:subfield[@code='b']">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">b</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:text> </xsl:text>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">c</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>

        </span>
    </xsl:template>
</xsl:stylesheet>

<!-- Stylus Studio meta-information - (c)1998-2002 eXcelon Corp.
<metaInformation>
<scenarios/><MapperInfo srcSchemaPath="" srcSchemaRoot="" srcSchemaPathIsRelative="yes" srcSchemaInterpretAsXML="no" destSchemaPath="" destSchemaRoot="" destSchemaPathIsRelative="yes" destSchemaInterpretAsXML="no"/>
</metaInformation>
-->
