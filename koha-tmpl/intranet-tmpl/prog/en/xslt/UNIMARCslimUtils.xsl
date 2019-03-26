<?xml version='1.0'?>

<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>

<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha-community.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  exclude-result-prefixes="marc items str">

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

  <xsl:template name="tag_210">
    <li>
      <strong>Publication: </strong>
      <xsl:for-each select="marc:datafield[@tag=210]">
        <span>
          <xsl:call-template name="addClassRtl" />
          <xsl:for-each select="marc:subfield">
            <xsl:choose>
              <xsl:when test="@code='c' or @code='g'">
                <xsl:if test="position()>1">
                  <xsl:text> : </xsl:text>
                </xsl:if>
                <xsl:value-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:if test="position()>1">
                  <xsl:text>, </xsl:text>
                </xsl:if>
                <xsl:value-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
          <xsl:if test="not (position() = last())">
            <xsl:text> • </xsl:text>
          </xsl:if>
        </span>
      </xsl:for-each>
    </li>
  </xsl:template>

	<xsl:template name="tag_215">
    <xsl:for-each select="marc:datafield[@tag=215]">
      <li>
        <strong>Description: </strong>
        <xsl:if test="marc:subfield[@code='a']">
          <xsl:value-of select="marc:subfield[@code='a']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='c']"> :
          <xsl:value-of select="marc:subfield[@code='c']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='d']"> ;
          <xsl:value-of select="marc:subfield[@code='d']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='e']"> +
          <xsl:value-of select="marc:subfield[@code='e']"/>
        </xsl:if>
      </li>
    </xsl:for-each>
  </xsl:template>

	<xsl:template name="tag_4xx">
    <xsl:for-each select="marc:datafield[@tag=464 or @tag=461]">
        <li>
        <strong>Linked with: </strong>
        <span>
          <xsl:call-template name="addClassRtl" />
          <xsl:if test="marc:subfield[@code='t']">
            <xsl:value-of select="marc:subfield[@code='t']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='e']"> :
            <xsl:value-of select="marc:subfield[@code='e']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='f']"> /
            <xsl:value-of select="marc:subfield[@code='f']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='v']">,
            <xsl:value-of select="marc:subfield[@code='v']"/>
          </xsl:if>
        </span>
      </li>
    </xsl:for-each>
  </xsl:template>

	<xsl:template name="subfieldSelect">
		<xsl:param name="codes"/>
		<xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subdivCodes"/>
		<xsl:param name="subdivDelimiter"/>
    <xsl:param name="urlencode"/>
		<xsl:variable name="str">
			<xsl:for-each select="marc:subfield">
				<xsl:if test="contains($codes, @code)">
                    <xsl:if test="contains($subdivCodes, @code)">
                        <xsl:value-of select="$subdivDelimiter"/>
                    </xsl:if>
					<xsl:value-of select="text()"/><xsl:value-of select="$delimeter"/>
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
      <xsl:param name="IntranetBiblioDefaultView"/>
      <xsl:choose>
          <xsl:when test="$IntranetBiblioDefaultView='normal'">
              <xsl:text>/cgi-bin/koha/catalogue/detail.pl?biblionumber=</xsl:text>
          </xsl:when>
          <xsl:when test="$IntranetBiblioDefaultView='isbd'">
              <xsl:text>/cgi-bin/koha/catalogue/ISBDdetail.pl?biblionumber=</xsl:text>
          </xsl:when>
          <xsl:when test="$IntranetBiblioDefaultView='labeled_marc'">
              <xsl:text>/cgi-bin/koha/catalogue/labeledMARCdetail.pl?biblionumber=</xsl:text>
          </xsl:when>
          <xsl:when test="$IntranetBiblioDefaultView='marc'">
              <xsl:text>/cgi-bin/koha/catalogue/MARCdetail.pl?biblionumber=</xsl:text>
          </xsl:when>
          <xsl:otherwise>
              <xsl:text>/cgi-bin/koha/catalogue/detail.pl?biblionumber=</xsl:text>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

	<xsl:template name="chopSpecialCharacters">
        <xsl:param name="title" />
        <xsl:variable name="ntitle"
             select="translate($title, '&#x0098;&#x009C;&#xC29C;&#xC29B;&#xC298;&#xC288;&#xC289;','')"/>
        <xsl:value-of select="$ntitle" />
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
    <xsl:text> </xsl:text>
	</xsl:template>

	<xsl:template name="addClassRtl">
    <xsl:variable name="lang" select="marc:subfield[@code='7']" />
    <xsl:if test="$lang = 'ha' or $lang = 'Hebrew' or $lang = 'fa' or $lang = 'Arabe'">
      <xsl:attribute name="class">rtl</xsl:attribute>
    </xsl:if>
  </xsl:template>

  <xsl:template name="tag_title">
    <xsl:param name="tag" />
    <xsl:param name="label" />
    <xsl:if test="marc:datafield[@tag=$tag]">
      <li>
        <strong><xsl:value-of select="$label"/>: </strong>
        <xsl:for-each select="marc:datafield[@tag=$tag]">
          <xsl:value-of select="marc:subfield[@code='a']" />
          <xsl:if test="marc:subfield[@code='d']">
            <xsl:text> : </xsl:text>
            <xsl:value-of select="marc:subfield[@code='e']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='e']">
            <xsl:for-each select="marc:subfield[@code='e']">
              <xsl:text> </xsl:text>
              <xsl:value-of select="."/>
            </xsl:for-each>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='f']">
            <xsl:text> / </xsl:text>
            <xsl:value-of select="marc:subfield[@code='f']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='h']">
            <xsl:text>, </xsl:text>
            <xsl:value-of select="marc:subfield[@code='h']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='i']">
            <xsl:text>, </xsl:text>
            <xsl:value-of select="marc:subfield[@code='i']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='v']">
            <xsl:text>, </xsl:text>
            <xsl:value-of select="marc:subfield[@code='v']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='x']">
            <xsl:text>, </xsl:text>
            <xsl:value-of select="marc:subfield[@code='x']"/>
          </xsl:if>
          <xsl:if test="marc:subfield[@code='z']">
            <xsl:text>, </xsl:text>
            <xsl:value-of select="marc:subfield[@code='z']"/>
          </xsl:if>
        </xsl:for-each>
      </li>
    </xsl:if>
  </xsl:template>


  <xsl:template name="tag_subject">
    <xsl:param name="tag" />
    <xsl:param name="label" />
    <xsl:if test="marc:datafield[@tag=$tag]">
      <li>
        <strong><xsl:value-of select="$label"/>: </strong>
        <xsl:for-each select="marc:datafield[@tag=$tag]">
          <a>
            <xsl:choose>
              <xsl:when test="marc:subfield[@code=9]">
                <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=an:<xsl:value-of select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=su:<xsl:value-of select="str:encode-uri(marc:subfield[@code='a'], true())"/></xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="chopPunctuation">
              <xsl:with-param name="chopString">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">abcdjptvxyz</xsl:with-param>
                    <xsl:with-param name="subdivCodes">jpxyz</xsl:with-param>
                    <xsl:with-param name="subdivDelimiter">-- </xsl:with-param>
                </xsl:call-template>
              </xsl:with-param>
            </xsl:call-template>
          </a>
          <xsl:if test="not (position()=last())">
            <xsl:text> | </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </li>
    </xsl:if>
  </xsl:template>


  <xsl:template name="tag_7xx">
    <xsl:param name="tag" />
    <xsl:param name="label" />
    <xsl:if test="marc:datafield[@tag=$tag]">
      <li>
        <strong><xsl:value-of select="$label" />: </strong>
        <xsl:for-each select="marc:datafield[@tag=$tag]">
          <span>
            <xsl:call-template name="addClassRtl" />
            <a>
              <xsl:choose>
                <xsl:when test="marc:subfield[@code=9]">
                  <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=an:<xsl:value-of select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=au:<xsl:value-of select="str:encode-uri(marc:subfield[@code='a'], true())"/><xsl:text> </xsl:text><xsl:value-of select="marc:subfield[@code='b']"/></xsl:attribute>
                </xsl:otherwise>
              </xsl:choose>
              <xsl:if test="marc:subfield[@code='a']">
                <xsl:value-of select="marc:subfield[@code='a']"/>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='b']">
                <xsl:text>, </xsl:text>
                <xsl:value-of select="marc:subfield[@code='b']"/>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='c']">
                <xsl:text>, </xsl:text>
                <xsl:value-of select="marc:subfield[@code='c']"/>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='d']">
                <xsl:text> </xsl:text>
                <xsl:value-of select="marc:subfield[@code='d']"/>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='f']">
                <span dir="ltr">
                <xsl:text> (</xsl:text>
                <xsl:value-of select="marc:subfield[@code='f']"/>
                <xsl:text>)</xsl:text>
                </span>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='g']">
                <xsl:text> </xsl:text>
                <xsl:value-of select="marc:subfield[@code='g']"/>
              </xsl:if>
              <xsl:if test="marc:subfield[@code='p']">
                <xsl:text> </xsl:text>
                <xsl:value-of select="marc:subfield[@code='p']"/>
              </xsl:if>
            </a>
          </span>
          <xsl:if test="not (position() = last())">
            <xsl:text> ; </xsl:text>
          </xsl:if>
        </xsl:for-each>
      </li>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
