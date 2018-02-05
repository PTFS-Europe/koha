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
use Encode;

#use Data::Dumper;
use C4::Auth qw( get_template_and_user);
use C4::Output qw(output_html_with_http_headers);
use C4::AgrovocWSService qw( simpleSearchByMode2 );

my $q = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'agrovoc/search.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 1,
        flagsrequired   => { catalogue => 1 },
        debug           => 1,
    }
);

my $op        = $q->param('op');
my $tag_index = $q->param('index');
if ( my $tool = $q->param('tool') ) {
    $template->param( tool => $tool );
}

if ($op) {
    if ( $op eq 'do_simple_search' ) {
        my $search_params = {};
        $search_params->{searchmode}   = $q->param('searchmode');
        $search_params->{searchstring} = $q->param('searchstring');
        $search_params->{languages}    = get_set_languages($q);
        my $arr_ref = call_simple_search($search_params);

        $template->param(
            term_array      => $arr_ref,
            ss_results_mode => 1,
        );
    }

}
else {
    get_set_languages($q);
}
if ($tag_index) {
    $template->param( tagindex => $tag_index );
}
output_html_with_http_headers( $q, $cookie, $template->output );

sub call_simple_search {
    my $sp = shift;
    my %langs;
    foreach ( @{ $sp->{languages} } ) {
        $langs{$_} = 1;
    }

    my $rs1 =
      simpleSearchByMode2( $sp->{searchstring}, $sp->{searchmode}, q{} );
    my $rs = encode( 'UTF-8', $rs1 );
    my $array_ref = [];

    #    my $rs = encode( 'utf8', $som->result );
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

sub get_set_languages {
    my $cgi_query = shift;
    my $lang_arr  = [];
    if ( $cgi_query->param('lang_english') ) {
        push @{$lang_arr}, 'EN';
        $template->param( lang_english => 'EN' );
    }
    if ( $cgi_query->param('lang_french') ) {
        push @{$lang_arr}, 'FR';
        $template->param( lang_french => 'FR' );
    }
    if ( $cgi_query->param('lang_spanish') ) {
        push @{$lang_arr}, 'ES';
        $template->param( lang_spanish => 'ES' );
    }
    if ( @{$lang_arr} == 0 ) {
        push @{$lang_arr}, 'EN';
        $template->param( lang_english => 'EN' );
    }
    return $lang_arr;
}
