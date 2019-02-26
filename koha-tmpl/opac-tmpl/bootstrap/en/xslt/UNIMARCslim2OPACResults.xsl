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
<xsl:key name="item-by-status" match="items:item" use="items:status"/>
<xsl:key name="item-by-status-and-branch-home" match="items:item" use="concat(items:status, ' ', items:homebranch)"/>
<xsl:key name="item-by-status-and-branch-holding" match="items:item" use="concat(items:status, ' ', items:holdingbranch)"/>

<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="marc:record">
  <xsl:variable name="leader" select="marc:leader"/>
  <xsl:variable name="leader6" select="substring($leader,7,1)"/>
  <xsl:variable name="leader7" select="substring($leader,8,1)"/>
  <xsl:variable name="biblionumber"
   select="marc:datafield[@tag=090]/marc:subfield[@code='a']"/>
  <xsl:variable name="isbn"
   select="marc:datafield[@tag=010]/marc:subfield[@code='a']"/>
  <xsl:variable name="OPACResultsLibrary" select="marc:sysprefs/marc:syspref[@name='OPACResultsLibrary']"/>
  <xsl:variable name="BiblioDefaultView" select="marc:sysprefs/marc:syspref[@name='BiblioDefaultView']"/>
  <xsl:variable name="hidelostitems" select="marc:sysprefs/marc:syspref[@name='hidelostitems']"/>
  <xsl:variable name="singleBranchMode" select="marc:sysprefs/marc:syspref[@name='singleBranchMode']"/>
  <xsl:variable name="OPACURLOpenInNewWindow" select="marc:sysprefs/marc:syspref[@name='OPACURLOpenInNewWindow']"/>

  <xsl:if test="marc:datafield[@tag=200]">
    <xsl:for-each select="marc:datafield[@tag=200]">
        <xsl:call-template name="addClassRtl" />
        <xsl:for-each select="marc:subfield">
          <xsl:choose>
            <xsl:when test="@code='a'">
              <xsl:variable name="title" select="."/>
              <xsl:variable name="ntitle"
                select="translate($title, '&#x0088;&#x0089;&#x0098;&#x009C;','')"/>
              <a>
                <xsl:attribute name="href">
                  <xsl:call-template name="buildBiblioDefaultViewURL">
                      <xsl:with-param name="BiblioDefaultView">
                          <xsl:value-of select="$BiblioDefaultView"/>
                      </xsl:with-param>
                  </xsl:call-template>
                  <xsl:value-of select="str:encode-uri($biblionumber, true())"/>
                </xsl:attribute>
                <xsl:attribute name="class">title</xsl:attribute>
                <xsl:value-of select="$ntitle" />
              </a>
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

  <xsl:call-template name="tag_210" />

  <xsl:call-template name="tag_215" />

  <span class="results_summary availability">
    <span class="label">Availability: </span>
    <xsl:choose>
      <xsl:when test="marc:datafield[@tag=856]">
        <xsl:for-each select="marc:datafield[@tag=856]">
          <xsl:choose>
            <xsl:when test="@ind2=0">
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
                    Click here to access online
                  </xsl:when>
                </xsl:choose>
              </a>
              <xsl:choose>
                <xsl:when test="position()=last()"></xsl:when>
                <xsl:otherwise> | </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
          </xsl:choose>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="count(key('item-by-status', 'available'))=0 and count(key('item-by-status', 'reference'))=0">
        No items available
      </xsl:when>
      <xsl:when test="count(key('item-by-status', 'available'))>0">
        <span class="available">
          <b><xsl:text>Items available for loan: </xsl:text></b>
          <xsl:variable name="available_items" select="key('item-by-status', 'available')"/>
      <xsl:choose>
      <xsl:when test="$singleBranchMode=1">
      <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
        <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber"> [<xsl:value-of select="items:itemcallnumber"/>]</xsl:if>
          <xsl:text> (</xsl:text>
          <xsl:value-of select="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))"/>
          <xsl:text>)</xsl:text>
          <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise></xsl:choose>
      </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
          <xsl:choose>
              <xsl:when test="$OPACResultsLibrary='homebranch'">
                  <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
                    <xsl:value-of select="items:homebranch"/>
                        <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">[<xsl:value-of select="items:itemcallnumber"/>]
                        </xsl:if>
                    <xsl:text> (</xsl:text>
                    <xsl:value-of select="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))"/>
                    <xsl:text>)</xsl:text>
                    <xsl:choose>
                      <xsl:when test="position()=last()">
                        <xsl:text>. </xsl:text>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:text>, </xsl:text>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-holding', concat(items:status, ' ', items:holdingbranch))[1])]">
                    <xsl:value-of select="items:holdingbranch"/>
                        <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">[<xsl:value-of select="items:itemcallnumber"/>]
                        </xsl:if>
                    <xsl:text> (</xsl:text>
                    <xsl:value-of select="count(key('item-by-status-and-branch-holding', concat(items:status, ' ', items:holdingbranch)))"/>
                    <xsl:text>)</xsl:text>
                    <xsl:choose>
                      <xsl:when test="position()=last()">
                        <xsl:text>. </xsl:text>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:text>, </xsl:text>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:for-each>
              </xsl:otherwise>
            </xsl:choose>
      </xsl:otherwise>
      </xsl:choose>
        </span>
      </xsl:when>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="count(key('item-by-status', 'reference'))>0">
        <span class="available">
          <b><xsl:text>Items available for reference: </xsl:text></b>
          <xsl:variable name="reference_items"
                        select="key('item-by-status', 'reference')"/>
          <xsl:for-each select="$reference_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
            <xsl:if test="$singleBranchMode=0">
                <xsl:value-of select="items:homebranch"/>
            </xsl:if>
            <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">[<xsl:value-of select="items:itemcallnumber"/>]</xsl:if>
            <xsl:text> (</xsl:text>
            <xsl:value-of select="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))"/>
            <xsl:text>)</xsl:text>
            <xsl:choose>
              <xsl:when test="position()=last()">
                <xsl:text>. </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>, </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </span>
      </xsl:when>
    </xsl:choose>
    <xsl:if test="count(key('item-by-status', 'Checked out'))>0">
      <span class="unavailable">
        <xsl:text>Checked out (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Checked out'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Withdrawn'))>0">
      <span class="unavailable">
        <xsl:text>Withdrawn (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Withdrawn'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="$hidelostitems='0' and count(key('item-by-status', 'Lost'))>0">
      <span class="unavailable">
        <xsl:text>Lost (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Lost'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Damaged'))>0">
      <span class="unavailable">
        <xsl:text>Damaged (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Damaged'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'On order'))>0">
      <span class="unavailable">
        <xsl:text>On order (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'On order'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'In transit'))>0">
      <span class="unavailable">
        <xsl:text>In transit (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'In transit'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
    <xsl:if test="count(key('item-by-status', 'Waiting'))>0">
      <span class="unavailable">
        <xsl:text>On hold (</xsl:text>
        <xsl:value-of select="count(key('item-by-status', 'Waiting'))"/>
        <xsl:text>). </xsl:text>
      </span>
    </xsl:if>
  </span>

</xsl:template>

</xsl:stylesheet>
