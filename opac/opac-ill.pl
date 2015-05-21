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
        flagsrequired   => { borrow => 1, ill => '*' },
    }
);

my $reply;
my $illRequests = Koha::ILLRequests->new;
my $query       = $cgi->param('query_value');
my $here        = "/cgi-bin/koha/opac-ill.pl";
my $op          = $cgi->param('op');
my ( $error, $message );
my $borrower    = Koha::Borrowers->new->find($borrowernumber)
    || die "You're logged in as the database user. We don't support that.";

if ( fail(1) ) {
    $error = {
        message => "missing_fields",
        op    => $op,
    };

} elsif ( $op eq 'new' ) {
    $template->param(
        branches => GetBranchesLoop($borrower->branchcode),
        types    => [ "Book", "Article", "Journal" ],
        back     => $here,
        forward  => $here . "?op=search",
        keywords => $cgi->param('keywords') || "",
        isbn     => $cgi->param('isbn')     || "",
        issn     => $cgi->param('issn')     || "",
        title    => $cgi->param('title')    || "",
        author   => $cgi->param('author')   || "",
        type     => $cgi->param('type')     || "",
    );

} elsif ( $op eq 'manual' ) {
    $template->param(
        branches => GetBranchesLoop($borrower->branchcode),
        types    => [ "Book", "Article", "Journal" ],
        back     => $here,
        forward  => $here . "?op=manual_action",
        fields   => $illRequests->prepare_manual_entry,
    );

} elsif ( $op eq 'search' ) {
    my $opts = {};
    $opts->{keywords} = $query if ( '' ne $query );
    my $nav_qry = "?op=search&query_value=" . uri_escape($query);
    for my $opt qw( isbn issn title author type start_rec max_results ) {
        my $val = $cgi->param($opt);
        if ( !fail($val)) {
            $opts->{$opt} = $val;
            $nav_qry .= "&${opt}=" . uri_escape($val)
                unless ${opt} eq "start_rec"; # handle paging separately.

        }
    }
    $reply = $illRequests->search_api($opts);
    my $search_strings = $illRequests->get_search_string;
    $template->param(
        search => $search_strings->{userstring},
        back   => $here . "?op=new&" . $search_strings->{querystring},
    );

    if ($reply) {
        # setup place request url
        my $rq_qry   = "?op=request" . "&query_value=";
        # Setup pagers
        my $page_qry = $nav_qry . "&start_rec=";
        my $pagers   = $illRequests->get_pagers(
            {
                next     => $page_qry,
                previous => $page_qry,
            }
        );
        $template->param(
            forward     => $here . "?op=request",
            next        => $pagers->{next},
            previous    => $pagers->{previous},
            rqp         => $rq_qry,
        );
    } else {
        $error = { message => 'api_search_fail', action => 'search' };
    }

} elsif ( $op eq 'request_comment' ) {
    my $request = $illRequests->find($query);
    $reply = $request->getForEditing( { opac => 1 } ),
    $template->param(
        forward => $here . "?op=request_update",
        back    => $here,
    );

} else {
    if ( $op eq 'request' ) {
        my $request = $illRequests->request( {
            uin      => $query,
            branch   => $borrower->branchcode,
            borrower => $borrower->borrowernumber,
        } );
        if (!$request) {
            $error = { message => 'request_placement_fail', action => 'request' };
        } else {
            $message = { message => 'request_placement_ok', uin => $query };
        }
    } elsif ( $op eq 'manual_request' ) {
        my %flds = $cgi->Vars;
        my $flds = {};
        while ( my ( $k, $v ) = each %flds ) {
            $flds->{$k} = $v if ( 'query_type' ne $k or 'query_value' );
        }
        # Rename borrower key
        $flds->{borrower} = $borrower->borrowernumber;
        my $request = $illRequests->request($flds);
        if (!$request) {
            $error = { message => 'request_placement_fail', action => 'request' };
        } else {
            $message = { message => 'request_placement_ok' };
        }

    } elsif ( $op eq 'request_cancellation') {
        my $request = $illRequests->find($query);
        if (!$request or !$request->editStatus( { status => "Cancellation Requested" } )) {
            $error = { message => 'request_cancellation_fail', action => 'cancellation' };
        } else {
            $message = { message => 'request_cancellation_ok', id => $query };
        }
    } elsif ( $op eq 'request_update') {
        my $request = $illRequests->find($query);
        my $comment = $cgi->param('primary_notes_opac');
        my $result = $request->editStatus(
            { 'primary_notes_opac' => $comment }
        );
        if ( $result ) {
            $message = {
                message => 'request_comment_ok',
                id      => $query,
                comment => $comment,
            };
        } else {
            $error = {
                message => 'request_comment_fail',
                action => 'comment'
            };
        }
    }
    $op = undef;
    my $requests = $illRequests->search($borrowernumber);
    if ($requests) {
        foreach my $rq ( @{$requests} ) {
            push @{$reply}, $rq->getSummary( { brw => 1 } );
        }
    }
    $template->param(
        cancel_url  => $here . "?op=request_cancellation&query_value=",
        comment_url => $here . "?op=request_comment&query_value=",
    );
}

$template->param(
    illview  => 1,
    query_value => $query,
    reply    => $reply,
    error    => $error,
    message  => $message,
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
