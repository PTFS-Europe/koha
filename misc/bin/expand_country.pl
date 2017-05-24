#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

# Copyright 2012 PTFS Europe Ltd

# Expand language headings on basis of 041 codes
# language in 546 should match codes in 041
#

use C4::Context;
use C4::Biblio qw/GetMarcBiblio ModBiblio/;
use Data::Dumper;
use MARC::Field;

my $dbh   = C4::Context->dbh;
my %lmap  = create_language_map();
my $total = 0;

#print Dumper( \%lmap ), "\n";

process();

#print $total, "\n";

sub process {
    my $sql = 'SELECT biblionumber FROM biblio';

    my $bibs = $dbh->selectall_arrayref($sql);
    for my $b ( @{$bibs} ) {
        process_bib( $b->[0] );
    }
    return;
}

sub process_bib {
    my $biblionumber = shift;
    my $bib          = GetMarcBiblio({biblionumber => $biblionumber, });

    if ( !$bib ) {
        print "Cannot retrieve bib for $biblionumber\n";
        return;
    }

    if ( change546($bib) ) {
        ModBiblio( $bib, $biblionumber, GetFrameworkCode($biblionumber) );
        ++$total;
    }
    return;
}

sub create_language_map {
    my $lang_arr = $dbh->selectall_arrayref(
q|SELECT authorised_value, lib from authorised_values where category = 'LANGFULL'|,
        { Slice => {} }
    );
    my %langfull;
    for my $row ( @{$lang_arr} ) {
        $langfull{ $row->{lib} } = $row->{authorised_value};
    }

    #    my %langfull = map { $_->{lib}, $_->{authorized_value} } @{$lang_arr};
    my $code_arr = $dbh->selectall_arrayref(
q|SELECT authorised_value, lib from authorised_values where category = 'LANGE'|,
        { Slice => {} }
    );
    my %code;
    for my $row ( @{$code_arr} ) {
        $code{ $row->{lib} } = $row->{authorised_value};
    }
    my %ret_hash;
    for my $c ( keys %code ) {
        if ( exists $langfull{$c} ) {
            $ret_hash{ $code{$c} } = $langfull{$c};
        }
    }
    return %ret_hash;

}

sub change546 {
    my $marcrec = shift;
    my $changed = 0;
    my @codes;
    my @fields = $marcrec->field('546');
    for my $t (@fields) {
        my @subfields = $t->subfield('a');
        push @codes, @subfields;
    }
    return unless @codes;
    my %languages;
    for my $c (@codes) {
        if ( exists $lmap{$c} ) {
            $languages{ $lmap{$c} } = 1;
        }
    }
    @fields = $marcrec->field('546');
    for my $t (@fields) {
        my @subfields = $t->subfield('a');
        for my $s (@subfields) {
            delete $languages{$s} if exists $languages{$s};
        }
    }

    my @fields_to_insert;
    for my $language ( keys %languages ) {
        my $new_field = MARC::Field->new( '546', ' ', ' ', 'a', $language );
        push @fields_to_insert, $new_field;
        $changed = 1;
    }
    if ($changed) {
        if (@fields_to_insert) {
            $marcrec->insert_fields_ordered(@fields_to_insert);
            return 1;
        }
    }
    return;
}
