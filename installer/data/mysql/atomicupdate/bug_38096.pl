use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "38096",
    description => "[DO NOT PUSH] Insert test data for 38096 test plan",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do you stuffs here
        $dbh->do(q{UPDATE biblio_metadata set metadata ='<?xml version="1.0" encoding="UTF-8"?>
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>03741njm a22006491a 4500</leader>
  <controlfield tag="001">12322942</controlfield>
  <controlfield tag="003">OSt</controlfield>
  <controlfield tag="005">20241007123044.0</controlfield>
  <controlfield tag="007">sd fungnn---eu</controlfield>
  <controlfield tag="008">981026s1998    mnumun   fi         mul d</controlfield>
  <datafield tag="010" ind1=" " ind2=" ">
    <subfield code="a">   00716040 </subfield>
  </datafield>
  <datafield tag="024" ind1="1" ind2=" ">
    <subfield code="a">021561601628</subfield>
  </datafield>
  <datafield tag="028" ind1="0" ind2="2">
    <subfield code="a">NSD6016</subfield>
    <subfield code="b">NorthSide</subfield>
  </datafield>
  <datafield tag="035" ind1=" " ind2=" ">
    <subfield code="a">(OCoLC)ocm40166468</subfield>
  </datafield>
  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">SVP</subfield>
    <subfield code="c">SVP</subfield>
    <subfield code="d">DLC</subfield>
  </datafield>
  <datafield tag="041" ind1="0" ind2=" ">
    <subfield code="d">mul</subfield>
    <subfield code="g">eng</subfield>
  </datafield>
  <datafield tag="042" ind1=" " ind2=" ">
    <subfield code="a">lcderive</subfield>
  </datafield>
  <datafield tag="043" ind1=" " ind2=" ">
    <subfield code="a">ev-----</subfield>
  </datafield>
  <datafield tag="050" ind1="0" ind2="0">
    <subfield code="a">NorthSide NSD6016</subfield>
  </datafield>
  <datafield tag="245" ind1="0" ind2="0">
    <subfield code="a">Nordic roots</subfield>
    <subfield code="h">[sound recording] :</subfield>
    <subfield code="b">a NorthSide collection.</subfield>
  </datafield>
  <datafield tag="260" ind1=" " ind2=" ">
    <subfield code="a">Minneapolis :</subfield>
    <subfield code="b">NorthSide,</subfield>
    <subfield code="c">[1998]</subfield>
  </datafield>
  <datafield tag="300" ind1=" " ind2=" ">
    <subfield code="a">1 sound disc :</subfield>
    <subfield code="b">digital ;</subfield>
    <subfield code="c">4 3/4 in.</subfield>
  </datafield>
  <datafield tag="500" ind1=" " ind2=" ">
    <subfield code="a">Folk, popular, and rock music.</subfield>
  </datafield>
  <datafield tag="500" ind1=" " ind2=" ">
    <subfield code="a">Compact disc.</subfield>
  </datafield>
  <datafield tag="500" ind1=" " ind2=" ">
    <subfield code="a">Program notes in English ([20] p. : col. ill.) inserted in container.</subfield>
  </datafield>
  <datafield tag="508" ind1=" " ind2=" ">
    <subfield code="a">Compiled by Robert Simonds.</subfield>
  </datafield>
  <datafield tag="511" ind1="0" ind2=" ">
    <subfield code="a">Various performers.</subfield>
  </datafield>
  <datafield tag="546" ind1=" " ind2=" ">
    <subfield code="a">Sung in Scandinavian languages.</subfield>
  </datafield>
  <datafield tag="650" ind1=" " ind2="0">
    <subfield code="a">Folk music</subfield>
    <subfield code="z">Scandinavia.</subfield>
    <subfield code="9">706</subfield>
  </datafield>
  <datafield tag="650" ind1=" " ind2="0">
    <subfield code="a">Folk dance music</subfield>
    <subfield code="z">Scandinavia.</subfield>
    <subfield code="9">707</subfield>
  </datafield>
  <datafield tag="650" ind1=" " ind2="0">
    <subfield code="a">Popular music</subfield>
    <subfield code="z">Scandinavia</subfield>
    <subfield code="y">1991-2000.</subfield>
    <subfield code="9">708</subfield>
  </datafield>
  <datafield tag="650" ind1=" " ind2="0">
    <subfield code="a">Rock music</subfield>
    <subfield code="z">Scandinavia</subfield>
    <subfield code="y">1991-2000.</subfield>
    <subfield code="9">709</subfield>
  </datafield>
  <datafield tag="700" ind1="1" ind2=" ">
    <subfield code="a">Rimestad, Hege.</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">61</subfield>
  </datafield>
  <datafield tag="700" ind1="0" ind2=" ">
    <subfield code="a">Wimme.</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">62</subfield>
  </datafield>
  <datafield tag="700" ind1="1" ind2=" ">
    <subfield code="a">Varis, Tapani.</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">63</subfield>
  </datafield>
  <datafield tag="700" ind1="1" ind2=" ">
    <subfield code="a">Johansson, Olov.</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">64</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Väsen (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">65</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Hedningarna (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">66</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Groupa (Musical Group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">67</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Chateau Neuf (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">68</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Swåp (Musica group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">69</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Loituma (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">70</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Garmarna (Musical group)</subfield>
    <subfield code="4">prf</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Hoven Droven (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">71</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Fule (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">72</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Troka (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">73</subfield>
  </datafield>
  <datafield tag="710" ind1="2" ind2=" ">
    <subfield code="a">Triakel (Musical group)</subfield>
    <subfield code="4">prf</subfield>
    <subfield code="9">74</subfield>
  </datafield>
  <datafield tag="856" ind1="4" ind2="2">
    <subfield code="z">Koha community no protocol</subfield>
    <subfield code="u">koha-community.org/</subfield>
  </datafield>
  <datafield tag="856" ind1="4" ind2="2">
    <subfield code="z">Koha community with protocol</subfield>
    <subfield code="u">https://koha-community.org/</subfield>
  </datafield>
  <datafield tag="856" ind1="4" ind2="2">
    <subfield code="z">Koha logo image</subfield>
    <subfield code="q">jpeg</subfield>
    <subfield code="u">https://koha-community.org/files/2013/09/cropped-kohabanner3.jpg</subfield>
  </datafield>
  <datafield tag="857" ind1="4" ind2="2">
    <subfield code="z">Koha community no protocol</subfield>
    <subfield code="u">koha-community.org/</subfield>
  </datafield>
  <datafield tag="857" ind1="4" ind2="2">
    <subfield code="z">Koha community with protocol</subfield>
    <subfield code="u">https://koha-community.org/</subfield>
  </datafield>
  <datafield tag="857" ind1="4" ind2="2">
    <subfield code="z">KohaCon 2024 logo image</subfield>
    <subfield code="q">jpeg</subfield>
    <subfield code="u">https://2024.kohacon.org/wp-content/uploads/2024/01/kohacon24_fr_verticale_vert_noir.png</subfield>
  </datafield>
  <datafield tag="906" ind1=" " ind2=" ">
    <subfield code="b">cbc</subfield>
    <subfield code="c">copycat</subfield>
    <subfield code="d">3</subfield>
    <subfield code="e">ncip</subfield>
    <subfield code="f">20</subfield>
    <subfield code="g">y-soundrec</subfield>
  </datafield>
  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="2">ddc</subfield>
    <subfield code="c">MU</subfield>
  </datafield>
  <datafield tag="999" ind1=" " ind2=" ">
    <subfield code="c">76</subfield>
    <subfield code="d">76</subfield>
  </datafield>
</record>' where biblionumber=76});


        # Other information
        say_info( $out, "Test data for 38096 added." );
    },
};
