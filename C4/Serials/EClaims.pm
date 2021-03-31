package C4::Serials::EClaims;
use strict;
use warnings;

use base qw(Exporter);
use Readonly;
use C4::Context;
use DateTime;
use Koha::Database;
use Koha::DateUtils;
use Carp;

our @EXPORT_OK = qw( format_claim get_buyer_ean, get_supplier_ean);

Readonly::Scalar my $seg_terminator      => q{'};
Readonly::Scalar my $separator           => q{+};
Readonly::Scalar my $component_separator => q{:};
Readonly::Scalar my $release_character   => q{?};

#
# This is format the arrayref of missingissues from claims.pl instead of formatting a message
# to send in email 
# format_clain(\@missing_issue, $bookseller_id)
#

sub format_claim {
    my $claims_arr = shift;
    my $supplier_id = shift;
    my ($buyer_ean,  $buyer_ean_type) = get_buyer_ean();
    if (!$buyer_ean) {
        carp "No ean set for claim";
        return;
    }
    my ($supplier_ean, $supplier_ean_type) = get_supplier_ean($supplier_id);
    if (!$supplier_ean) {
        carp "No san defined for supplier $supplier_id";
        return;
    }
    my $message = q{};
    my $reference = int rand(99_999_999_999_999);
    # UNA
    $message .= q{UNA:+.? '};
    # UNB
    my $dt = DateTime->now();
    my $message_date = $dt->ymd(q{});
    $message .= interchange_header(
        $message_date, $buyer_ean, $buyer_ean_type, $supplier_ean, $supplier_ean_type,$reference);
    # UNH
    my $segment_count = 1;
    $message .= "UNH+${reference}+OSTENQ:D:96A:UN:EAN002'";
    # BGM
    $message .= "BGM+92J::28+${reference}+9'";
    ++$segment_count;
    # DTM
    $message .= "DTM+137:$message_date:102'";
    ++$segment_count;
    # NAD+BY
    $message .= "NAD+BY+${buyer_ean}'";
    ++$segment_count;
    # NAD+SU
    $message .= "NAD+SU+${supplier_ean}'";
    ++$segment_count;
    # DOC
    $message .= "DOC+220+VARIOUS'";
    ++$segment_count;
    # Claim line
    my $line_id = 0;
    foreach my $claimLine (@{$claims_arr}) {
    # LIN
        ++$line_id;
        $message .= "LIN+${line_id}'"; 
        ++$segment_count;
    # PIA
        if ($claimLine->{issn}) {
            my $issn = $claimLine->{issn};
            $message .= "PIA+5+$issn:IS'";
            ++$segment_count;
        }
    # IMD (050/109/080)
       if ($claimLine->{title}) {
           my $title = encode_text($claimLine->{title});
           $message .= "IMD+L+050+:::$title'";
           ++$segment_count;
       }
    # STS
    #  Hardcoded as the serials package does not allow for the various codes included in
    #  Edifact specifications
        $message .= q{STS+UP1::9+CSD::9+55'};
        ++$segment_count;
    # RFF+LI
    # RFF+SNA
    # RFF+SNL
        $message .= "RFF+SNL:$claimLine->{serialid}'";
        ++$segment_count;
    # RFF+ACT
    # DTM
    #  I think claimdate is too vague to quote here
    # QTY
    # hardcoded to claim 1 issue as we dont seem to accurately have a figure
        $message .= q{QTY+73:1'};
        ++$segment_count;
    } # claimLine
    # Summary
    # UNT
    ++$segment_count;   # include this segment
    $message .= "UNT+$segment_count+${reference}$seg_terminator";
    # UNZ
    $message .= "UNZ+3+$reference'";
    return $message;
}

sub format_segment {
    my $segment = shift;
    my $s = q{};    # text representation of segment
    foreach my $element (@{$segment}) {
        
    }
    return $s;
}

sub interchange_header {
    my ($message_date, $buyer_ean, $buyer_ean_type, $supplier_ean, $supplier_ean_type, $reference) = @_;
    my $hdr = q{UNB+UNOC:3};
    $hdr .= $buyer_ean;  # include type of id in these
    $hdr .= ":$buyer_ean_type";
    $hdr .= $separator;
    $hdr .= $supplier_ean;
    $hdr .= ":$supplier_ean_type";
    $hdr .= $separator;
    $hdr .= $message_date;
    $hdr .= $separator;
    $hdr .= $reference;
    $hdr .= $seg_terminator;

    return $hdr;
}

sub encode_text {
    my $string = shift;
    if ($string) {
        $string =~ s/[?]/??/g;
        $string =~ s/'/?'/g;
        $string =~ s/:/?:/g;
        $string =~ s/[+]/?+/g;
    }
    return $string;
}

sub get_buyer_ean {

    my $dbh = C4::Context->dbh;

    my $eans = $dbh->selectrow_arrayref('select ean, id_code_qualifier from edifact_ean');

    return( $eans->[0], $eans->[1]);
}

sub get_supplier_ean {
    my $bookseller_id = shift;

    my $dbh = C4::Context->dbh;

    my $eans = $dbh->selectrow_arrayref(
        'select san, id_code_qualifier from vendor_edi_accounts where vendor_id = ?',
        {}, $bookseller_id);

    return( $eans->[0], $eans->[1]);
}

1;

