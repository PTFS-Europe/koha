#!/usr/bin/perl

# Copyright (C) 2010,2011,2013  PTFS-Europe Ltd.

# This file is part of Koha.

# Koha is program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Koha; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;

use CGI;
use JSON;
use Carp;

use C4::AgrovocWSService
  qw( getConceptInfoByTermcode getTermByLanguage getDefinitions);

my $q    = CGI->new;
my $lang = $q->param('lang');
$lang ||= 'en';

my $concept = retrieve_concept(scalar $q->param('termcode'), $lang );
my $label = shift  @{ $concept->{labels} };

#$template->param(
#    display_term_details => 1,
#    termcode             => $concept->{termcode},
#    labels               => $label,
#    UF                   => $concept->{UF},
#    USE                  => $concept->{USE},
#    BT                   => $concept->{BT},
#    NT                   => $concept->{NT},
#    RT                   => $concept->{RT},
#    DEF                  => $concept->{Definitions},
#    ALTLANG              => $concept->{other_lang},
#    termlang             => $lang,
#);

print $q->header( -type => 'application/json', -charset => 'utf-8' );
my $json = {
    labels   => $label,
    termlang => $lang,
    concept  => $concept,
};

my $json_text = encode_json $json;

print $json_text;

sub retrieve_concept {
    my $termcode = shift;
    my $language = shift;
    if (!$termcode) {
        return;
    }
    my %lang_map = (
        EN => 'English',
        FR => 'French',
        ES => 'Spanish',
    );
    my @concept_array = getConceptInfoByTermcode($termcode);

    my $concept_hash = {};
    $concept_hash->{termcode} = shift @concept_array;
    $concept_hash->{termcode} =~ s/^\[//;    # remove surrounding [ ]
    $concept_hash->{termcode} =~ s/\]$//;
    my $other_avail_lang = {};

    my $labels  = shift @concept_array;
    my $arr_ref = [];
    if ( $labels =~ m/\[(.*)\]/ ) {
        $labels = $1;
        my @l_arr = split /,\s*/, $labels;
        while (@l_arr) {
            my $term   = shift @l_arr;
            my $l_lang = shift @l_arr;
            if ( $l_lang !~ m/^(?:\p{PosixUpper}{2}|\p{PosixUpper}{2}-\p{PosixUpper}{2})$/ ) {
                $term .= ", $l_lang";
                $l_lang = shift @l_arr;
            }

            if ( $language eq $l_lang ) {
                push @{$arr_ref}, $term;
                next;
            }
            if ( exists $lang_map{$l_lang} ) {
                $other_avail_lang->{$l_lang} = $lang_map{$l_lang};
            }
        }
    }
    $concept_hash->{labels}     = $arr_ref;
    $concept_hash->{other_lang} = [];
    for my $code ( sort keys %{$other_avail_lang} ) {
        push @{ $concept_hash->{other_lang} },
          {
            langcode => $code,
            langname => $other_avail_lang->{$code},
          };
    }
    for my $element (@concept_array) {
        my @arr         = _string2array($element);
        my $array_label = shift @arr;
        $concept_hash->{$array_label} = \@arr;
    }

    for my $arr_label (qw( UF USE BT NT RT )) {
        my $tmp_arr = [];   # cannot do this in place as we need to remove terms
                            # which lack a label in the interface language
        foreach my $tc ( @{ $concept_hash->{$arr_label} } ) {
            if ($tc=~/^[A-Z]{3}$/) {
                next;
            }
            if ($tc!~/^[0-9abcdef]+$/) {
                push @{$tmp_arr},
                {
                    termcode => $tc,
                    label    => 'CANNOT RETRIEVE',
                    language => $language,
                };
                next;
            }
            my $term_label;
            eval { $term_label = getTermByLanguage( $tc, $language ); };
            if ($@) {
                carp "getTerm:$tc:$@";
                next;
            }
            if ($term_label) {
                push @{$tmp_arr},
                  {
                    termcode => $tc,
                    label    => $term_label,
                    language => $language,
                  };
            }
        }
        $concept_hash->{$arr_label} = $tmp_arr;
    }
    $concept_hash->{Definitions} = getDefinitions( $termcode, $language );
    if ( $concept_hash->{Definitions} ) {
        $concept_hash->{Definitions} =~ s/^\s*//;
        if ( $concept_hash->{Definitions} eq q{[Scope Note:]} ) {
            $concept_hash->{Definitions} = q{};
        }
    }
    else {
        $concept_hash->{Definitions} = q{};
    }

    return $concept_hash;
}

sub _string2array {
    my $string = shift;
    $string =~ s/^\[//;
    $string =~ s/\]$//;
    return split /,\s*/, $string;
}
