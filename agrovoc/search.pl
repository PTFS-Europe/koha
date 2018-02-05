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

use C4::AgrovocWSService qw( simpleSearchByMode2 );

my $q = CGI->new;

my $op = $q->param('op');

if ($op) {
    if ( $op eq 'search' ) {
        my $search_params = {};
        $search_params->{searchmode}   = $q->param('searchmode');
        $search_params->{searchstring} = $q->param('searchstring');

        my @languages = $q->param('language');
        $search_params->{languages} = \@languages;

        # $search_params->{languages}    = get_set_languages($q);
        my $arr_ref = call_simple_search($search_params);

        my $json_text = encode_json $arr_ref;

        print $q->header( -type => 'application/json', -charset => 'utf-8' );
        print $json_text;
    }

}

sub call_simple_search {
    my $sp = shift;
    my %langs;
    foreach ( @{ $sp->{languages} } ) {
        $langs{$_} = 1;
    }

    my $rs =
      simpleSearchByMode2( $sp->{searchstring}, $sp->{searchmode}, q{} );
    my $array_ref = [];

    if ( $rs =~ m/^\[(.*)\]/ ) {
        $rs = $1;
        my @elements = split /\|\|/, $rs;

        while (@elements) {
            my $termcode     = shift @elements;
            my $matched_term = shift @elements;
            my $language     = uc shift @elements;
            if ( $termcode eq 'NumberOfResults' ) {
                last;
            }
            if ( !$language || !exists $langs{$language} ) {
                next;
            }
            push @{$array_ref},
              {
                termcode    => $termcode,
                matchedTerm => $matched_term,
                language    => $language,
              };
        }
    }
    return $array_ref;
}
