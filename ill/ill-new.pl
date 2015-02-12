#!/usr/bin/perl

# Copyright 2013 PTFS-Europe Ltd and Mark Gavillet
# Copyright 2014 PTFS-Europe Ltd
#
# This file is part of Koha.
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Search qw(GetDistinctValues);
use C4::Context;
use Koha::ILLRequests;
use URI::Escape;

my $input = CGI->new;
my $reply = [];
my $action = $input->param('query_type') || 'new';
my $query = $input->param('query_value') || '';

my ( $template, $borrowernumber, $cookie )
  = get_template_and_user(
                          {
                           template_name => 'ill/ill-new.tt',
                           query         => $input,
                           type          => 'intranet',
                           flagsrequired => { ill => 1 },
                          }
                         );

$template->param( query_value => $query );
$template->param( query_type => $action );

if ( $action eq 'search' and $query ) {
    my $opts = {};
    my $nav_qry = "?query_type=search&query_value=" . uri_escape($query);
    for my $opt qw( isbn issn title author type start_rec max_results ) {
        my $val = $input->param($opt);
        if ( $val ne '' ) {
            $opts->{$opt} = $val;
            $nav_qry .= "&${opt}=" . uri_escape($val);
        }
    }
    $reply = Koha::ILLRequests->new()->search_api($query, $opts);
    my $max_results = $opts->{max_results} || 10;
    my $results = @{$reply};
    my $bcounter = $input->param('start_rec') || 1;
    my $ncounter = $bcounter + $results;
    my $pcounter = $bcounter - $results;
    my $next = 0;
    $next = $nav_qry . "&start_rec=" . $ncounter
      if ( $results == $max_results );
    my $prev = 0;
    $prev = $nav_qry . "&start_rec=" . $pcounter
      if ( $pcounter > 1 ) ;
    $template->param( next => $next );
    $template->param( prev => $prev );
    my $rq_qry = "?query_type=request";
    $rq_qry .= "&brw=" . $input->param('brw') if ($input->param ne '');
    $rq_qry .= "&query_value=";
    $template->param( rqp => $rq_qry );

} else {                        # or action eq 'new'
    $template->param( type => [ "Book", "Article", "Journal" ] );
}

$template->param( recv => $input );
$template->param( reply => $reply );
$template->param( debug => 1 ); # if ( $input->param('debug') );

output_html_with_http_headers( $input, $cookie, $template->output );
