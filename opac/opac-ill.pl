#!/usr/bin/perl

# Copyright 2012 Mark Gavillet & PTFS Europe
# Copyright 2014 PTFS Europe Ltd
#
# This file is part of Koha.
#
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
use C4::Context;
use C4::Koha;
use C4::Output;
use C4::Branch;
use Koha::Borrowers;
use Koha::ILLRequests;
use URI::Escape;

my $cgi = CGI->new();

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-ill.tt',
        query           => $cgi,
        type            => 'opac',
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $reply;
my $query    = $cgi->param('query_value');
my $here     = "/cgi-bin/koha/opac-ill.pl";
my $op       = $cgi->param('op');
my $error    = 0;
my $borrower = Koha::Borrowers->new->find($borrowernumber)
    || die "You're logged in as the database user. We don't support that.";

if ( fail(1) ) {
    $error = {
        error => "missing_fields",
        op    => $op,
    };

} elsif ( $op eq 'new' ) {
    $template->param(
        branches => GetBranchesLoop($borrower->branchcode),
        type     => [ "Book", "Article", "Journal" ],
        back     => $here,
        forward  => $here . "?op=search",
    );

} elsif ( $op eq 'search' ) {
    my $opts = {};
    my $nav_qry = "?op=search&query_value=" . uri_escape($query);
    for my $opt qw( isbn issn title author type start_rec max_results ) {
        my $val = $cgi->param($opt);
        if ( !fail($val)) {
            $opts->{$opt} = $val;
            $nav_qry .= "&${opt}=" . uri_escape($val);
        }
    }
    $reply = Koha::ILLRequests->new()->search_api($query, $opts);
    if ($reply) {
        my $max_results = $opts->{max_results} || 10;
        my $results  = @{$reply || []};
        my $bcounter = $cgi->param('start_rec') || 1;
        my $ncounter = $bcounter + $results;
        my $pcounter = $bcounter - $results;
        my $next = 0;
        $next = $nav_qry . "&start_rec=" . $ncounter
          if ( $results == $max_results );
        my $prev = 0;
        $prev = $nav_qry . "&start_rec=" . $pcounter
          if ( $pcounter > 1 ) ;
        my $rq_qry = "?op=request";
        $rq_qry .= "&query_value=";
        $template->param(
            back        => $here . "?op=search",
            forward     => $here . "?op=request",
            next        => $next,
            prev        => $prev,
            rqp         => $rq_qry,
        );
    } else {
        $error = { error => 'api', action => 'search' };
    }
    my $search_string;
    ($query) ? $opts->{keywords} = $query : $opts;
    while ( my ($type, $value) = each $opts ) {
        $search_string .= "[" . join(": ", $type, $value) . "]";
    }
    $template->param(search => $search_string);
} else {
    if ( $op eq 'request' ) {
        my $request = Koha::ILLRequests->new->request( {
            uin      => $query,
            branch   => $borrower->branchcode,
            borrower => $borrower->borrowernumber,
        } );
        if (!$request) {
            $error = { error => 'unknown', action => 'request' };
        }
    } elsif ( $op eq 'request_cancellation') {
        my $request = @{Koha::ILLRequests->new->retrieve_ill_request($query) || [0]}[0];
        if (!$request or !$request->editStatus( { status => "Cancellation Requested" } )) {
            $error = { error => 'unknown', action => 'cancellation' };
        }
    }
    $op = undef;
    my $requests = Koha::ILLRequests->new->retrieve_ill_requests($borrowernumber);
    if ($requests) {
        foreach my $rq ( @{$requests} ) {
            push @{$reply}, $rq->getSummary;
        }
    }
    $template->param(
        cancel_url => $here . "?op=request_cancellation&query_value=",
    );
}

$template->param(
    illview  => 1,
    query_value => $query,
    reply    => $reply,
    error    => $error,
    op       => $op,
);

output_html_with_http_headers( $cgi, $cookie, $template->output );

sub fail {
    my @values = @_;
    foreach my $val ( @values ) {
        return 1 if (!$val or $val eq '');
    }
    return 0;
}
