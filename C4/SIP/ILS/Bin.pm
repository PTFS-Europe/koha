package C4::SIP::ILS::Bin;
use strict;
use warnings;
use base qw( Exporter );

our @EXPORT_OK = qw( get_sort_bin);

my $sort = {
    AAB => {
        AABCD => 4,
        PLAW  => 4,
    },
    AB => {
        AF    => 6,
        ASFIC => 6,
        ASNF  => 6,
        CFIC  => 6,
        CLAS  => 1,
        CNF   => 6,
        CRIM  => 1,
        HFIC  => 6,
        HNF   => 6,
        HOR   => 1,
        LLL   => 3,
        LOCL  => 2,
        LP    => 6,
        NCOL  => 2,
        NF    => 3,
        RGS   => 7,
        ROM   => 1,
        SCIFI => 1,
        SEA   => 1,
        WEST  => 1,
    },
    BDVD => {
        DVD => 4,
    },
    BIBS => {
        BIBS => 7,
    },
    BRD => {
        BLU => 4,
    },
    CAS => {
        LANG => 3,
        CD   => 4,
    },
    CD => {
        CD => 4,
    },
    EXFIC => {
        AF => 1,
    },
    FAVDVD => {
        DVD => 4,
    },
    FDV => {
        DVD => 3,
    },
    GN13 => {
        AF => 5,
    },
    GN16 => {
        AF => 1,
    },
    JAB => {
        JAB => 5,
    },
    JB => {
        ASJUN => 5,
        CJUN  => 5,
        EY    => 5,
        JF    => 5,
        JLP   => 5,
        JNF   => 5,
        JRG   => 7,
        PICT  => 5,
        RA    => 5,
    },
    JDVD => {
        JDVD => 5,
    },
    JVID => {
        JDVD => 5,
    },
    LANGCD => {
        AF => 3,
    },
    MAG => {
        NF => 7,
    },
    MAKE => {
        MAKE => 7,
    },
    MISC => {
        CD => 4,
    },
    MUS => {
        BLU   => 4,
        CLA   => 4,
        COU   => 4,
        FMT   => 4,
        FOL   => 4,
        JAZ   => 4,
        LIBCD => 4,
        LIG   => 4,
        POP   => 4,
        VOC   => 4,
        WOR   => 4,
    },
    NEWS => {
        NEWS => 7,
    },
    OL => {
        NF => 3,
    },
    PER => {
        ASPER => 6,
        CPER  => 6,
    },
    PROJ => {
        PROJ => 7,
    },
    REF => {
        REF => 7,
    },
    SPC => {
        AF => 7,
    },
    STAFF => {
        STAFF => 7,
    },
    SUB => {
        ASSUB => 7,
        CSUB  => 7,
    },
    TB => {
        TEENF  => 5,
        TEENNF => 5,
    },
    TWO_WK => {
        AF => 7,
    },
    VID => {
        FLV => 3,
        JFV => 5,
        RV  => 4,
    },
    WBOLLY => {
        DVD => 4,
    },
    WDVD => {
        DVD => 4,
    },
};

sub get_sort_bin {
    my ( $itemtype, $location ) = @_;

    if ( !defined $itemtype ) {
        return 99;
    }
    if ( $itemtype eq 'TOY' ) {
        return 7;
    }
    if ( !defined $location ) {
        return 99;
    }
    if ( exists $sort->{$itemtype}->{$location} ) {
        return $sort->{$itemtype}->{$location};
    }
    return 99;
}

1;
