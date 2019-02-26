<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>

<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha-community.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  exclude-result-prefixes="marc items str">

<xsl:import href="UNIMARCslimUtils.xsl"/>
<xsl:output method = "html" indent="yes" omit-xml-declaration = "yes" encoding="UTF-8"/>
<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="marc:record">
  <xsl:variable name="leader" select="marc:leader"/>
  <xsl:variable name="leader6" select="substring($leader,7,1)"/>
  <xsl:variable name="leader7" select="substring($leader,8,1)"/>
  <xsl:variable name="biblionumber" select="marc:datafield[@tag=090]/marc:subfield[@code='a']"/>
  <xsl:variable name="DisplayOPACiconsXSLT" select="marc:sysprefs/marc:syspref[@name='DisplayOPACiconsXSLT']"/>
  <xsl:variable name="OPACURLOpenInNewWindow" select="marc:sysprefs/marc:syspref[@name='OPACURLOpenInNewWindow']"/>
  <xsl:variable name="URLLinkText" select="marc:sysprefs/marc:syspref[@name='URLLinkText']"/>

  <xsl:if test="marc:datafield[@tag=200]">
    <xsl:for-each select="marc:datafield[@tag=200]">
      <h1 class="title">
        <xsl:call-template name="addClassRtl" />
        <xsl:for-each select="marc:subfield">
          <xsl:choose>
            <xsl:when test="@code='a'">
              <xsl:variable name="title" select="."/>
              <xsl:variable name="ntitle"
               select="translate($title, '&#x0088;&#x0089;&#x0098;&#x009C;','')"/>
              <xsl:value-of select="$ntitle" />
            </xsl:when>
            <xsl:when test="@code='b'">
              <xsl:text> [</xsl:text>
              <xsl:value-of select="."/>
              <xsl:text>]</xsl:text>
            </xsl:when>
            <xsl:when test="@code='d'">
              <xsl:text> = </xsl:text>
              <xsl:value-of select="."/>
            </xsl:when>
            <xsl:when test="@code='e'">
              <xsl:text> : </xsl:text>
              <xsl:value-of select="."/>
            </xsl:when>
            <xsl:when test="@code='f'">
              <xsl:text> / </xsl:text>
              <xsl:value-of select="."/>
            </xsl:when>
            <xsl:when test="@code='g'">
              <xsl:text> ; </xsl:text>
              <xsl:value-of select="."/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>, </xsl:text>
              <xsl:value-of select="."/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </h1>
    </xsl:for-each>
  </xsl:if>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">454</xsl:with-param>
    <xsl:with-param name="label">Translation of</xsl:with-param>
    <xsl:with-param name="spanclass">original_title</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">461</xsl:with-param>
    <xsl:with-param name="label">Set Level</xsl:with-param>
    <xsl:with-param name="spanclass">set_level</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">464</xsl:with-param>
    <xsl:with-param name="label">Piece-Analytic Level</xsl:with-param>
    <xsl:with-param name="spanclass">piece_analytic_level</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">700</xsl:with-param>
    <xsl:with-param name="label">Main Author</xsl:with-param>
    <xsl:with-param name="spanclass">main_author</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">710</xsl:with-param>
    <xsl:with-param name="label">Corporate Author (Main)</xsl:with-param>
    <xsl:with-param name="spanclass">corporate_main_author</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">701</xsl:with-param>
    <xsl:with-param name="label">Coauthor</xsl:with-param>
    <xsl:with-param name="spanclass">coauthor</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">702</xsl:with-param>
    <xsl:with-param name="label">Secondary Author</xsl:with-param>
    <xsl:with-param name="spanclass">secondary_author</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">711</xsl:with-param>
    <xsl:with-param name="label">Corporate Author (Coauthor)</xsl:with-param>
    <xsl:with-param name="spanclass">corporate_coauthor</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_7xx">
    <xsl:with-param name="tag">712</xsl:with-param>
    <xsl:with-param name="label">Corporate Author (Secondary)</xsl:with-param>
    <xsl:with-param name="spanclass">corporate_secondary_author</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">500</xsl:with-param>
    <xsl:with-param name="label">Uniform Title</xsl:with-param>
    <xsl:with-param name="spanclass">uniform_title</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">503</xsl:with-param>
    <xsl:with-param name="label">Uniform Conventional Heading</xsl:with-param>
    <xsl:with-param name="spanclass">uniform_conventional_heading</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=101]">
    <span class="results_summary language">
      <span class="label">Language: </span>
      <xsl:for-each select="marc:datafield[@tag=101]">
        <xsl:for-each select="marc:subfield">
          <xsl:choose>
            <xsl:when test="@code='b'">of intermediate text, </xsl:when>
            <xsl:when test="@code='c'">of original work, </xsl:when>
            <xsl:when test="@code='d'">of summary, </xsl:when>
            <xsl:when test="@code='e'">of contents page, </xsl:when>
            <xsl:when test="@code='f'">of title page, </xsl:when>
            <xsl:when test="@code='g'">of title proper, </xsl:when>
            <xsl:when test="@code='h'">of libretto, </xsl:when>
            <xsl:when test="@code='i'">of accompanying material, </xsl:when>
            <xsl:when test="@code='j'">of subtitles, </xsl:when>
          </xsl:choose>
          <xsl:value-of select="text()"/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text> ; </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=102]">
	  <span class="results_summary country">
      <span class="label">Country: </span>
      <xsl:for-each select="marc:datafield[@tag=102]">
        <xsl:for-each select="marc:subfield">
          <xsl:value-of select="text()"/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
              <xsl:otherwise><xsl:text>, </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:call-template name="tag_comma">
    <xsl:with-param name="tag">205</xsl:with-param>
    <xsl:with-param name="label">Edition Statement</xsl:with-param>
    <xsl:with-param name="spanclass">edition</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_210" />

  <xsl:call-template name="tag_215" />

  <!-- Build ISBN -->
  <xsl:if test="marc:datafield[@tag=010]/marc:subfield[@code='a']">
    <span class="results_summary isbn"><span class="label">ISBN: </span>
      <xsl:for-each select="marc:datafield[@tag=010]/marc:subfield[@code='a']">
        <span property="isbn">
          <xsl:value-of select="."/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>; </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </span>
      </xsl:for-each>
    </span>
  </xsl:if>

  <!-- Build ISSN -->
  <xsl:if test="marc:datafield[@tag=011]/marc:subfield[@code='a']">
    <span class="results_summary issn"><span class="label">ISSN: </span>
      <xsl:for-each select="marc:datafield[@tag=011]/marc:subfield[@code='a']">
        <span property="issn">
          <xsl:value-of select="."/>
          <xsl:choose>
            <xsl:when test="position()=last()">
              <xsl:text>.</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>; </xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </span>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:call-template name="tag_title">
    <xsl:with-param name="tag">225</xsl:with-param>
    <xsl:with-param name="label">Series</xsl:with-param>
    <xsl:with-param name="spanclass">series</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=676]">
    <span class="results_summary dewey">
    <span class="label">Dewey: </span>
      <xsl:for-each select="marc:datafield[@tag=676]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:if test="marc:subfield[@code='v']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='v']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='z']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='z']"/>
        </xsl:if>
        <xsl:if test="not (position()=last())">
          <xsl:text> ; </xsl:text>
        </xsl:if>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=686]">
    <span class="results_summary classification">
    <span class="label">Classification: </span>
      <xsl:for-each select="marc:datafield[@tag=686]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:if test="marc:subfield[@code='b']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='b']"/>
        </xsl:if>
        <xsl:if test="marc:subfield[@code='c']">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="marc:subfield[@code='c']"/>
        </xsl:if>
        <xsl:if test="not (position()=last())"><xsl:text> ; </xsl:text></xsl:if>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=327]">
    <span class="results_summary contents">
      <span class="label">Contents note: </span>
      <xsl:for-each select="marc:datafield[@tag=327]">
        <xsl:call-template name="chopPunctuation">
          <xsl:with-param name="chopString">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">abcdjpvxyz</xsl:with-param>
                <xsl:with-param name="subdivCodes">jpxyz</xsl:with-param>
                <xsl:with-param name="subdivDelimiter">-- </xsl:with-param>
            </xsl:call-template>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=330]">
    <span class="results_summary abstract">
      <span class="label">Abstract: </span>
      <xsl:for-each select="marc:datafield[@tag=330]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose>
          <xsl:when test="position()=last()">
            <xsl:text>.</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>; </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=317]">
    <span class="results_summary provenance">
      <span class="label">Provenance note: </span>
      <xsl:for-each select="marc:datafield[@tag=317]">
          <xsl:value-of select="marc:subfield[@code='a']"/>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=320]">
    <span class="results_summary bibliography">
      <span class="label">Bibliography: </span>
      <xsl:for-each select="marc:datafield[@tag=320]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=328]">
    <span class="results_summary thesis">
      <span class="label">Thesis: </span>
      <xsl:for-each select="marc:datafield[@tag=328]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=333]">
    <span class="results_summary audience">
      <span class="label">Audience: </span>
      <xsl:for-each select="marc:datafield[@tag=333]">
        <xsl:value-of select="marc:subfield[@code='a']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:if test="marc:datafield[@tag=955]">
    <span class="results_summary sudoc_serial_history">
      <span class="label">SUDOC serial history: </span>
      <xsl:for-each select="marc:datafield[@tag=955]">
        <xsl:value-of select="marc:subfield[@code='9']"/>:
        <xsl:value-of select="marc:subfield[@code='r']"/>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><xsl:text>; </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">600</xsl:with-param>
    <xsl:with-param name="label">Subject - Personal Name</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">601</xsl:with-param>
    <xsl:with-param name="label">Subject - Corporate Author</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">602</xsl:with-param>
    <xsl:with-param name="label">Subject - Family</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">604</xsl:with-param>
    <xsl:with-param name="label">Subject - Author/Title</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">606</xsl:with-param>
    <xsl:with-param name="label">Subject - Topical Name</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">607</xsl:with-param>
    <xsl:with-param name="label">Subject - Geographical Name</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">608</xsl:with-param>
    <xsl:with-param name="label">Subject - Form</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">610</xsl:with-param>
    <xsl:with-param name="label">Subject</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">615</xsl:with-param>
    <xsl:with-param name="label">Subject Category</xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="tag_subject">
    <xsl:with-param name="tag">616</xsl:with-param>
    <xsl:with-param name="label">Trademark</xsl:with-param>
  </xsl:call-template>

  <xsl:if test="marc:datafield[@tag=856]">
    <span class="results_summary online_resources">
      <span class="label">Online Resources:</span>
      <xsl:for-each select="marc:datafield[@tag=856]">
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="marc:subfield[@code='u']"/>
          </xsl:attribute>
          <xsl:if test="$OPACURLOpenInNewWindow='1'">
            <xsl:attribute name="target">_blank</xsl:attribute>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="marc:subfield[@code='y' or @code='3' or @code='z']">
              <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">y3z</xsl:with-param>
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="not(marc:subfield[@code='y']) and not(marc:subfield[@code='3']) and not(marc:subfield[@code='z'])">
              <xsl:choose>
                <xsl:when test="$URLLinkText!=''">
                  <xsl:value-of select="$URLLinkText"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:text>Click here to access online</xsl:text>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
          </xsl:choose>
        </a>
        <xsl:choose>
          <xsl:when test="position()=last()"></xsl:when>
          <xsl:otherwise> | </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </span>
  </xsl:if>
</xsl:template>

    <xsl:template name="nameABCDQ">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">aq</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
                <xsl:with-param name="punctuation">
                    <xsl:text>:,;/ </xsl:text>
                </xsl:with-param>
            </xsl:call-template>
        <xsl:call-template name="termsOfAddress"/>
    </xsl:template>

    <xsl:template name="nameABCDN">
        <xsl:for-each select="marc:subfield[@code='a']">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="."/>
                </xsl:call-template>
        </xsl:for-each>
        <xsl:for-each select="marc:subfield[@code='b']">
                <xsl:value-of select="."/>
        </xsl:for-each>
        <xsl:if test="marc:subfield[@code='c'] or marc:subfield[@code='d'] or marc:subfield[@code='n']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">cdn</xsl:with-param>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="nameACDEQ">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">acdeq</xsl:with-param>
            </xsl:call-template>
    </xsl:template>
    <xsl:template name="termsOfAddress">
        <xsl:if test="marc:subfield[@code='b' or @code='c']">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">bc</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="part">
        <xsl:variable name="partNumber">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">n</xsl:with-param>
                <xsl:with-param name="anyCodes">n</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="partName">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">p</xsl:with-param>
                <xsl:with-param name="anyCodes">p</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="string-length(normalize-space($partNumber))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partNumber"/>
                </xsl:call-template>
        </xsl:if>
        <xsl:if test="string-length(normalize-space($partName))">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString" select="$partName"/>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="specialSubfieldSelect">
        <xsl:param name="anyCodes"/>
        <xsl:param name="axis"/>
        <xsl:param name="beforeCodes"/>
        <xsl:param name="afterCodes"/>
        <xsl:variable name="str">
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($anyCodes, @code)      or (contains($beforeCodes,@code) and following-sibling::marc:subfield[@code=$axis])      or (contains($afterCodes,@code) and preceding-sibling::marc:subfield[@code=$axis])">
                    <xsl:value-of select="text()"/>
                    <xsl:text> </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="substring($str,1,string-length($str)-1)"/>
    </xsl:template>

</xsl:stylesheet>
