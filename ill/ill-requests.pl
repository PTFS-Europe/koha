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
use C4::Branch;
use C4::Context;
use C4::Output;
use C4::Search qw(GetDistinctValues);
use Koha::Borrowers;
use Koha::ILLRequests;
use URI::Escape;

my $input = CGI->new;
my $illRequests = Koha::ILLRequests->new;
my $reply = [];
my $type = $input->param('query_type');
my $query = $input->param('query_value');

if ( !$query and !$type ) {
    $type = 'requests';
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user( {
    template_name => 'ill/ill-requests.tt',
    query         => $input,
    type          => 'intranet',
    flagsrequired => { ill => '*' },
} );

$template->param( query_value => $query );
$template->param( query_type => $type );
$template->param( recv => $input );

if ( $type eq 'request' and $query
         and $input->param('brw')
         and $input->param('branch') ) {
    my $request = $illRequests->request( {
        uin      => $query,
        branch   => $input->param('branch'),
        borrower => $input->param('brw'),
    } );
    push(@{$reply}, $request->getSummary( { brw => 1 } )) if ($request);

} else {
    my $requests;
    if ( $type eq 'filter' ) {
        $requests = $illRequests->search( {
            cardnumber      => $input->param('borrower_filter')    || 0,
            branch          => $input->param('branch_filter')      || 0,
            status          => $input->param('status_filter')      || 0,
            placement_date  => $input->param('placed_filter')      || 0,
            ts              => $input->param('modified_filter')    || 0,
            completion_date => $input->param('completed_filter')   || 0,
            required_date   => $input->param('required_by_filter') || 0, # dummy
            reqtype         => $input->param('type_filter')        || 0,
        } );
    } else {
        $requests = $illRequests->search;
    }
    foreach my $rq ( @{$requests} ) {
        push @{$reply}, $rq->getSummary( { brw => 1 } );
    }
    my $manage_url = "/cgi-bin/koha/ill/ill-manage.pl?op=view&rq=";
    $template->param( manage_url => $manage_url );
}

$template->param(
    reply    => $reply,
    branches => GetBranchesLoop,
    types    => [ "Book", "Article", "Journal" ],
    statuses => [ "New Request", "Queued", "Completed",
                  "Cancellation Requested"]
);

output_html_with_http_headers( $input, $cookie, $template->output );
