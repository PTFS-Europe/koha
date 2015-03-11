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
use C4::Branch; # GetBranches
use C4::Output;
use C4::Search qw(GetDistinctValues);
use C4::Context;
use Koha::ILLRequests;
use URI::Escape;

my $input = CGI->new;
my $reply = [];
my $error = 0;
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

if ( fail($query, $input->param('brw'), $input->param('branch')) ) {
    $error = {
        error => "missing_fields",
        action => $action,
    };

} elsif ( $action eq 'search' ) {
    my $opts = {};
    my $nav_qry = "?query_type=search&query_value=" . uri_escape($query);
    for my $opt qw( isbn issn title author type start_rec max_results ) {
        my $val = $input->param($opt);
        if ( $val ne '' ) {
            $opts->{$opt} = $val;
            $nav_qry .= "&${opt}=" . uri_escape($val)
                unless $ {opt} eq "start_rec"; # handle paging separately.
        }
    }
    my $requests = Koha::ILLRequests->new;
    $reply = $requests->search_api($query, $opts);
    if ($reply) {
        # setup place request url
        my $rq_qry = "?query_type=request";
        $rq_qry .= "&brw=" . $input->param('brw');
        $rq_qry .= "&branch=" . $input->param('branch');
        $rq_qry .= "&query_value=";
        # Setup pagers
        my $page_qry = $nav_qry . "&start_rec=";
        my $pagers   = $requests->get_pagers(
            {
                next     => $page_qry,
                previous => $page_qry,
            }
        );
        $template->param(
            next        => $pagers->{next},
            previous    => $pagers->{previous},
            rqp    => $rq_qry,
        );
    } else {
        $error = { error => "api", action => "search" }
    }
    ($query) ? $opts->{keywords} = $query : $opts;
    my $search_string;
    while ( my ($type, $value) = each $opts ) {
        $search_string .= "[" . join(": ", $type, $value) . "]";
    }
    $template->param(search => $search_string);

} else {                        # or action eq 'new'
}

$template->param( type => [ "Book", "Article", "Journal" ] );
$template->param( recv     => $input );
$template->param( branches => GetBranchesLoop );
$template->param( reply    => $reply );
$template->param( error    => $error );
$template->param( debug    => 1 ); # if ( $input->param('debug') );

output_html_with_http_headers( $input, $cookie, $template->output );

sub fail {
    my @values = @_;
    foreach my $val ( @values ) {
        return 1 if (!$val or $val eq '');
    }
    return 0;
}
