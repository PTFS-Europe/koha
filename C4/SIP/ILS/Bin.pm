#
# ILS::Bin.pm
# 
# A Class for configuring sorting rules for SIP Sorter bins for the OpenSIP
# system
#

package C4::SIP::ILS::Bin;

use strict;
use warnings;
use base qw( Exporter );

use C4::SIP::Sip qw(siplog);

our @EXPORT_OK = qw( get_sort_bin );

#Sorting criteria:
# Floor 1 (Bin 1) 000-599  but NOT 340-369 
# Floor 2 (Bin 2) 600-658.39 
# Floor 3 (Bin 3) 658.4-999 
# Floor 3 (Bin 4) 340-369.9 
# Exceptions (Bin 5) : reservations, CD/DVD, music scores *, home site RBH, next day loan, same day
# loan, Reference,
# * Item types : PMUS, DVDL,DVDS, DVDX, CD, CDS
# In terms of the sorter config the current checks are
# 1) Check item status 106=&gt; Bin 5
# 2) Check site RBH =&gt; Bin 5
# 3) Check item type PMUS, DVDL, DVDS, DVDX, CD, CDS, REST, SAME =&gt; Bin 5
# 4) Check sequence REST =&gt; Bin 5
# 5) Check Classmark
# 000-339.99999 =&gt; Bin 1
# 340-369.999999 =&gt; Bin 4
# 370-599.999999 =&gt; Bin 1
# 600-658.399999 =&gt; Bin 2
# 658.4-999.999999 =&gt; Bin 3
#else Bin 5

# library (branchcode) -> location (floor) -> classmark
my $map = {
    'PHL'   => {
        '340'   => 1,
        '370'   => 4,
        '658.5' => 1,
        '999'   => 3
    },
    'BERKS' => {
        '340'   => 1,
        '370'   => 4,
        '658.5' => 1,
        '999'   => 3
    }
};

my $exceptions = {
    'CD'     => 5,
    'NDLCD'  => 5,
    'DVD'    => 5,
    'DVD18'  => 5,
    'NDLDVD' => 5,
    'ILL'    => 5,
    'SCORE'  => 5
};

sub get_sort_bin {
    my ( $item, $library ) = @_;
    my $itemtype = $item->effective_itemtype;
    my $item_classmark = $item->itemcallnumber;

    my $bin = 5;

    # Handle itemtype exceptions
    $bin = $exceptions->{$itemtype} if exists($exceptions->{$itemtype});

    # Handle mappings
    if ( exists ( $map->{$library} ) ) {
        for my $classmark ( sort keys %{$map->{$library}} ) {
	    if ( $item_classmark < $map->{$library}->{$classmark} ) {
                $bin = $map->{$library}->{$classmark};
                last;
	    }
	}
    }
    
    return $bin;
}

1;
