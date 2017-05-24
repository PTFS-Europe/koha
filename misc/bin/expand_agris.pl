#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

# Copyright 2012 PTFS-Europe Ltd
#
# Expands agris codes to agris headings
use C4::Context;
use C4::Biblio qw/GetMarcBiblio ModBiblio GetFrameworkCode/;
use Data::Dumper;
use MARC::Field;

my $dbh         = C4::Context->dbh;
my %agris_codes = get_agris();
my %hmap;
foreach ( keys %agris_codes ) {
    $hmap{ $agris_codes{$_} } = $_;
}

#print Dumper( \%agris_codes );
my $total_processed;
process();

#print $total_processed, "\n";

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
    my $bib          = GetMarcBiblio( { biblionumber => $biblionumber, });

    if ( !$bib ) {
        print "Cannot retrieve bib for $biblionumber\n";
        return;
    }
    if ( correct_agris($bib) ) {
        ModBiblio( $bib, $biblionumber, GetFrameworkCode($biblionumber) );
        ++$total_processed;
    }

    return;
}

sub correct_agris {
    my $marcrec = shift;
    my $changed = 0;
    my @delete_list;
    my %req_headings;

    my @code_fields = $marcrec->field('072');
    foreach my $code_tag (@code_fields) {
        my @code_sf = $code_tag->subfield('a');
        unless (@code_sf) {
            push @delete_list, $code_tag;
            $changed = 1;
            next;
        }
        foreach my $c (@code_sf) {
            if ( $c =~ m/^([A-Z]\d\d)/ ) {
                my $code = $1;
                if ( exists $hmap{$code} ) {
                    $req_headings{$code} = 1;
                }
            }
        }
    }
    my @headings = $marcrec->field('690');

    for my $heading_tag (@headings) {
        my $text = $heading_tag->subfield('a');
        if ( !$text ) {

            # empty delete
            push @delete_list, $heading_tag;
            next;
        }

        # unmatched report
        if ( $text =~ m/^([A-Z]\d\d)/ ) {
            my $code = $1;
            if ( exists $req_headings{$code} ) {
                delete $req_headings{$code};
            }
        }

    }
    my @add_list;
    foreach my $h ( keys %req_headings ) {
        my $new_field = MARC::Field->new(
            '690', q{ }, '7',
            '2' => 'agrissce',
            a   => $hmap{$h},
        );
        push @add_list, $new_field;

    }
    if (@delete_list) {
        $marcrec->delete_field(@delete_list);
        $changed = 1;
    }
    if (@add_list) {
        $marcrec->insert_fields_ordered(@add_list);
        $changed = 1;
    }
    return $changed;

}

sub get_agris {
    my %rethash;
    my $aref = $dbh->selectall_arrayref(
q|SELECT authorised_value, lib from authorised_values where category = 'AGRISCC'|,
        {}
    );
    foreach my $row ( @{$aref} ) {
        $rethash{ $row->[0] } = $row->[1];
    }

    return %rethash;
}
