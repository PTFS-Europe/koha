package Koha::Edifact::Line;

# Copyright 2014 PTFS-Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use strict;
use warnings;

use MARC::Record;
use MARC::Field;
use Carp;

sub new {
    my ( $class, $data_array_ref ) = @_;
    my $self = _parse_lines($data_array_ref);

    bless $self, $class;
    return $self;
}

# helper routine used by constructor
# creates the hashref used as a data structure by the Line object

sub _parse_lines {
    my $aref = shift;

    my $lin = shift @{$aref};

    my $d = {
        line_item_number       => $lin->elem(0),
        item_number_id         => $lin->elem( 2, 0 ),
        additional_product_ids => [],
    };
    my @item_description;

    foreach my $s ( @{$aref} ) {
        if ( $s->tag eq 'PIA' ) {
            push @{ $d->{additional_product_ids} },
              {
                function_code => $s->elem(0),
                item_number   => $s->elem( 1, 0 ),
                number_type   => $s->elem( 1, 1 ),
              };
        }
        elsif ( $s->tag eq 'IMD' ) {
            push @item_description, $s;
        }
        elsif ( $s->tag eq 'QTY' ) {
            $d->{quantity} = $s->elem( 0, 1 );
        }
        elsif ( $s->tag eq 'DTM' ) {
            $d->{avaiability_date} = $s->elem( 0, 1 );
        }
        elsif ( $s->tag eq 'GIR' ) {

            # we may get a Gir for each copy if QTY > 1
            if ( !$d->{GIR} ) {
                $d->{GIR} = [];
            }
            push @{ $d->{GIR} }, extract_gir($s);

        }
        elsif ( $s->tag eq 'FTX' ) {

            my $type = $s->elem(1);
            if ( $type eq 'LNO' ) {    # Ingrams Oasis Internal Notes field
                $type = 'internal_notes';
            }
            else {
                $type = 'free_text';
            }

            my $ftx = $s->elem(3);
            if ( ref $ftx eq 'ARRAY' ) {   # it comes in 70 character components
                $ftx = join ' ', @{$ftx};
            }
            if ( exists $d->{$type} ) {    # we can only catenate repeats
                $d->{$type} .= q{ };
                $d->{$type} .= $ftx;
            }
            else {
                $d->{$type} = $ftx;
            }
        }
        elsif ( $s->tag eq 'MOA' ) {

            $d->{monetary_amount} = $s->elem( 0, 1 );
        }
        elsif ( $s->tag eq 'PRI' ) {

            $d->{price} = $s->elem( 0, 1 );
        }
        elsif ( $s->tag eq 'RFF' ) {
            my $qualifier = $s->elem( 0, 0 );
            if ( $qualifier eq 'QLI' ) { # Suppliers unique quotation linenumber
                $d->{reference} = $s->elem( 0, 1 );
            }
            elsif ( $qualifier eq 'LI' ) {    # Buyer's unique orderline number
                $d->{ordernumber} = $s->elem( 0, 1 );
            }
        }
    }
    $d->{item_description} = _format_item_description(@item_description);
    $d->{segs}             = $aref;

    return $d;
}

sub _format_item_description {
    my @imd    = @_;
    my $bibrec = {};

 # IMD : +Type code 'L' + characteristic code 3 char + Description in comp 3 & 4
    foreach my $imd (@imd) {
        my $type_code = $imd->elem(0);
        my $ccode     = $imd->elem(1);
        my $desc      = $imd->elem( 2, 3 );
        if ( $imd->elem( 2, 4 ) ) {
            $desc .= $imd->elem( 2, 4 );
        }
        if ( $type_code ne 'L' ) {
            carp
              "Only handles text item descriptions at present: code=$type_code";
            next;
        }
        if ( exists $bibrec->{$ccode} ) {
            $bibrec->{$ccode} .= q{ };
            $bibrec->{$ccode} .= $desc;
        }
        else {
            $bibrec->{$ccode} = $desc;
        }
    }
    return $bibrec;
}

sub marc_record {
    my $self = shift;
    my $b    = $self->{item_description};

    my $bib = MARC::Record->new();

    my @spec;
    my @fields;
    if ( exists $b->{'010'} ) {
        @spec = qw( 100 a 011 c 012 b 013 d 014 e );
        push @fields, new_field( $b, [ 100, 1, q{ } ], @spec );
    }
    if ( exists $b->{'020'} ) {
        @spec = qw( 020 a 021 c 022 b 023 d 024 e );
        push @fields, new_field( $b, [ 700, 1, q{ } ], @spec );
    }

    # corp conf
    if ( exists $b->{'030'} ) {
        push @fields, $self->corpcon(1);
    }
    if ( exists $b->{'040'} ) {
        push @fields, $self->corpcon(7);
    }
    if ( exists $b->{'050'} ) {
        @spec = qw( '050' a '060' b '065' c );
        push @fields, new_field( $b, [ 245, 1, 0 ], @spec );
    }
    if ( exists $b->{100} ) {
        @spec = qw( 100 a 101 b);
        push @fields, new_field( $b, [ 250, q{ }, q{ } ], @spec );
    }
    @spec = qw( 110 a 120 b 170 c );
    my $f = new_field( $b, [ 260, q{ }, q{ } ], @spec );
    if ($f) {
        push @fields, $f;
    }
    @spec = qw( 180 a 181 b 182 c 183 e);
    $f = new_field( $b, [ 300, q{ }, q{ } ], @spec );
    if ($f) {
        push @fields, $f;
    }
    if ( exists $b->{190} ) {
        @spec = qw( 190 a);
        push @fields, new_field( $b, [ 490, q{ }, q{ } ], @spec );
    }

    if ( exists $b->{200} ) {
        @spec = qw( 200 a);
        push @fields, new_field( $b, [ 490, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{210} ) {
        @spec = qw( 210 a);
        push @fields, new_field( $b, [ 490, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{300} ) {
        @spec = qw( 300 a);
        push @fields, new_field( $b, [ 500, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{310} ) {
        @spec = qw( 310 a);
        push @fields, new_field( $b, [ 520, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{320} ) {
        @spec = qw( 320 a);
        push @fields, new_field( $b, [ 521, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{260} ) {
        @spec = qw( 260 a);
        push @fields, new_field( $b, [ 600, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{270} ) {
        @spec = qw( 270 a);
        push @fields, new_field( $b, [ 650, q{ }, q{ } ], @spec );
    }
    if ( exists $b->{280} ) {
        @spec = qw( 280 a);
        push @fields, new_field( $b, [ 655, q{ }, q{ } ], @spec );
    }

    # class
    if ( exists $b->{230} ) {
        @spec = qw( 230 a);
        push @fields, new_field( $b, [ '082', q{ }, q{ } ], @spec );
    }
    if ( exists $b->{240} ) {
        @spec = qw( 240 a);
        push @fields, new_field( $b, [ '084', q{ }, q{ } ], @spec );
    }
    $bib->insert_fields_ordered(@fields);

    return $bib;
}

sub corpcon {
    my ( $self, $level ) = @_;
    my $test_these = {
        1 => [ '033', '032', '034' ],
        7 => [ '043', '042', '044' ],
    };
    my $conf = 0;
    foreach my $t ( @{ $test_these->{$level} } ) {
        if ( exists $self->{item_description}->{$t} ) {
            $conf = 1;
        }
    }
    my $tag;
    my @spec;
    my ( $i1, $i2 ) = ( q{ }, q{ } );
    if ($conf) {
        $tag = ( $level * 100 ) + 11;
        if ( $level == 1 ) {
            @spec = qw( 030 a 031 e 032 n 033 c 034 d);
        }
        else {
            @spec = qw( 040 a 041 e 042 n 043 c 044 d);
        }
    }
    else {
        $tag = ( $level * 100 ) + 10;
        if ( $level == 1 ) {
            @spec = qw( 030 a 031 b);
        }
        else {
            @spec = qw( 040 a 041 b);
        }
    }
    return new_field( $self->{item_description}, [ $tag, $i1, $i2 ], @spec );
}

sub new_field {
    my ( $b, $tag_ind, @sfd_elem ) = @_;
    my @sfd;
    while (@sfd_elem) {
        my $e = shift @sfd_elem;
        my $c = shift @sfd_elem;
        if ( exists $b->{$e} ) {
            push @sfd, $c, $b->{$e};
        }
    }
    if (@sfd) {
        my $field = MARC::Field->new( @{$tag_ind}, @sfd );
        return $field;
    }
    return;
}

# Accessor methods to line data

sub item_number_id {
    my $self = shift;
    return $self->{item_number_id};
}

sub line_item_number {
    my $self = shift;
    return $self->{line_item_number};
}

sub additional_product_ids {
    my $self = shift;
    return $self->{additional_product_ids};
}

sub item_description {
    my $self = shift;
    return $self->{item_description};
}

sub monetary_amount {
    my $self = shift;
    return $self->{monetary_amount};
}

sub quantity {
    my $self = shift;
    return $self->{quantity};
}

sub price {
    my $self = shift;
    return $self->{price};
}

sub reference {
    my $self = shift;
    return $self->{reference};
}

sub ordernumber {
    my $self = shift;
    return $self->{ordernumber};
}

sub free_text {
    my $self = shift;
    return $self->{free_text};
}

sub internal_notes {
    my $self = shift;
    return $self->{internal_notes};
}

# item_desription_fields accessors

sub title {
    my $self       = shift;
    my $titlefield = q{050};
    if ( exists $self->{item_description}->{$titlefield} ) {
        return $self->{item_description}->{$titlefield};
    }
    return;
}

sub author {
    my $self  = shift;
    my $field = q{010};
    if ( exists $self->{item_description}->{$field} ) {
        return $self->{item_description}->{$field};
    }
    return;
}

sub series {
    my $self  = shift;
    my $field = q{190};
    if ( exists $self->{item_description}->{$field} ) {
        return $self->{item_description}->{$field};
    }
    return;
}

sub publisher {
    my $self  = shift;
    my $field = q{120};
    if ( exists $self->{item_description}->{$field} ) {
        return $self->{item_description}->{$field};
    }
    return;
}

sub publication_date {
    my $self  = shift;
    my $field = q{170};
    if ( exists $self->{item_description}->{$field} ) {
        return $self->{item_description}->{$field};
    }
    return;
}

sub girfield {
    my ( $self, $field, $occ ) = @_;

    # defaults to occurence 0 returns undef if occ requested > occs
    if ( defined $occ && $occ > @{ $self->{GIR} } ) {
        return;
    }
    $occ ||= 0;
    return $self->{GIR}->[$occ]->{$field};
}

sub extract_gir {
    my $s    = shift;
    my %qmap = (
        LAC => 'barcode',
        LCL => 'classification',
        LFN => 'fund_allocation',
        LLN => 'loan_category',
        LLO => 'branch',
        LSM => 'shelfmark',
        LSQ => 'collection_code',
        LST => 'stock_category',
        LVT => 'servicing_instruction',
        LCO => 'item_unique_id',
    );

    my $set_qualifier = $s->elem( 0, 0 );    # copy number
    my $gir_element = { copy => $set_qualifier, };
    my $element = 1;
    while ( my $e = $s->elem($element) ) {
        ++$element;
        if ( exists $qmap{ $e->[1] } ) {
            my $qualifier = $qmap{ $e->[1] };
            $gir_element->{$qualifier} = $e->[0];
        }
        else {

            carp "Unrecognized GIR code : $e->[1] for $e->[0]";
        }
    }
    return $gir_element;
}

# mainly for invoice processing amt_ will derive from MOA price_ from PRI and tax_ from TAX/MOA pairsn
sub moa_amt {
    my ( $self, $qualifier ) = @_;
    foreach my $s ( @{ $self->{segs} } ) {
        if ( $s->tag eq 'MOA' && $s->elem( 0, 0 ) eq $qualifier ) {
            return $s->elem( 0, 1 );
        }
    }
    return;
}

sub amt_discount {
    my $self = shift;
    return $self->moa_amt('52');
}

sub amt_prepayment {
    my $self = shift;
    return $self->moa_amt('113');
}

# total including allowances & tax
sub amt_total {
    my $self = shift;
    return $self->moa_amt('128');
}

sub amt_unitprice {
    my $self = shift;
    return $self->moa_amt('146');
}

# item amount after allowances excluding tax
sub amt_lineitem {
    my $self = shift;
    return $self->moa_amt('146');
}

sub pri_price {
    my ( $self, $price_qualifier ) = @_;
    foreach my $s ( @{ $self->{segs} } ) {
        if ( $s->tag eq 'PRI' && $s->elem( 0, 0 ) eq $price_qualifier ) {
            return {
                price          => $s->elem( 0, 1 ),
                type           => $s->elem( 0, 2 ),
                type_qualifier => $s->elem( 0, 3 ),
            };
        }
    }
    return;
}

# unit price that will be chaged excl tax
sub price_net {
    my $self = shift;
    my $p    = $self->pri_price('AAA');
    if ( defined $p ) {
        return $p->{price};
    }
    return;
}

# unit price excluding all allowances, charges and taxes
sub price_gross {
    my $self = shift;
    my $p    = $self->pri_price('AAB');
    if ( defined $p ) {
        return $p->{price};
    }
    return;
}

# information price incl tax excluding allowances, charges
sub price_info {
    my $self = shift;
    my $p    = $self->pri_price('AAE');
    if ( defined $p ) {
        return $p->{price};
    }
    return;
}

# information price incl tax,allowances, charges
sub price_info_inclusive {
    my $self = shift;
    my $p    = $self->pri_price('AAE');
    if ( defined $p ) {
        return $p->{price};
    }
    return;
}

sub tax {
    my $self = shift;
    return $self->moa_amt('124');
}

1;
__END__

=head1 NAME
   Koha::Edifact::Line

=head1 SYNOPSIS

  Class to abstractly handle a Line in an Edifact Transmission

=head1 DESCRIPTION

  Allows access to Edifact line elements by name

=head1 BUGS


=head1 Methods

=head2 new

   Called with an array ref of segments constituting the line

=head1 AUTHOR

   Colin Campbell <colin.campbell@ptfs-europe.com>


=head1 COPYRIGHT

   Copyright 2014, PTFS-Europe Ltd
   This program is free software, You may redistribute it under
   under the terms of the GNU General Public License


=cut
