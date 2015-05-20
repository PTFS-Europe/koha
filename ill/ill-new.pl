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
use C4::Members;
use C4::Output;
use C4::Search qw(GetDistinctValues);
use C4::Context;
use Koha::ILLRequests;
use URI::Escape;

my $input = CGI->new;
my $illRequests = Koha::ILLRequests->new;
my $reply = [];
my $error = 0;
my $action = $input->param('query_type') || 'new';
# FIXME: Query value is missing for Manual Entry.  This whole .pl needs to be
# refactored to do a way with query_type and query_value...
my $query = $input->param('query_value') || '';

my ( $template, $borrowernumber, $cookie ) = get_template_and_user( {
    template_name => 'ill/ill-new.tt',
    query         => $input,
    type          => 'intranet',
    flagsrequired => { ill => '*' },
} );

$template->param(
    query_value => $query,
    query_type  => $action,
);
my ( $brw_count, $brw ) = validate_borrower($input->param('brw'));

if ( $input->param('query_type') eq 'manual' ) {
    $reply = $illRequests->prepare_manual_entry;
    $template->param(
        forward => 'manual_action',
    );
} elsif ( fail($query, $input->param('branch')) ) {
    $error = { error => "missing_branch", action => $action };
} elsif ( !GetBranchDetail($input->param('branch')) ) {
    $error = { error => "invalid_branch", action => $action };
} elsif ( $brw_count == 0 ) {
    $error = { error => "invalid_borrower", action => $action };
} elsif ( $brw_count > 1 ) {
    my $forward = $input->param('query_type');
    my %flds = $input->Vars;
    my $flds = {};
    while ( my ( $k, $v ) = each %flds ) {
        if ( 'query_type' ne $k or 'query_value' ne $k or 'brw' ne $k ) {
            $flds->{$k} = $v;
        }
    }
    $template->param(
        flds         => $flds,
        query_type   => 'borrowers',
        borrowers    => $brw,
        branch       => $input->param('branch'),
        surname      => $input->param('brw'),
        forward      => $forward,
        query_value  => $query,
    );
} elsif ( $action eq 'search' ) {
    my $opts = {};
    $opts->{keywords} = $query if ( '' ne $query );
    my $nav_qry = "?query_type=search&query_value=" . uri_escape($query);
    for my $opt qw( isbn issn title author type start_rec max_results ) {
        my $val = $input->param($opt);
        if ( $val ne '' ) {
            $opts->{$opt} = $val;
            $nav_qry .= "&${opt}=" . uri_escape($val)
                unless $ {opt} eq "start_rec"; # handle paging separately.
        }
    }
    $reply = $illRequests->search_api($opts);
    my $search_strings = $illRequests->get_search_string;
    $template->param(
        search => $search_strings->{userstring},
        back   => "?op=new&" . $search_strings->{querystring},
    );

    if ($reply) {
        # setup place request url
        my $rq_qry = "?query_type=request";
        $rq_qry .= "&brw=" . $brw->borrowernumber;
        $rq_qry .= "&branch=" . $input->param('branch');
        $rq_qry .= "&query_value=";
        # Setup pagers
        my $page_qry = $nav_qry . "&start_rec=";
        my $pagers   = $illRequests->get_pagers(
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
        $error = { error => "api", action => "search" };
    }

} elsif ( 'manual_action' eq $action ) {
    # Currently we just Echo.  We also want to display nice results Labels etc.
    my $names = $illRequests->prepare_manual_entry;
    my %flds = $input->Vars;
    my $flds = {};
    while ( my ( $k, $v ) = each %flds ) {
        my $name = $names->{$k};
        if ( !$name ) {
            $name = "";
            $name = "Branch"   if ( 'branch' eq $k);
            if ( 'brw' eq $k ) {
                $name = "Borrower";
                $v    = $brw->borrowernumber;
            }
        }
        $flds->{$k} = [ $name, $v];
        $flds->{primary_manual} = [ "", "true" ];
    }
    $template->param(
        flds         => $flds,
    );
} else {                        # or action eq 'new'
}

$template->param(
    types    => [ "Book", "Article", "Journal" ],
    keywords => $input->param('keywords') || "",
    isbn     => $input->param('isbn')     || "",
    issn     => $input->param('issn')     || "",
    title    => $input->param('title')    || "",
    author   => $input->param('author')   || "",
    type     => $input->param('type')     || "",
    recv     => $input,
    branches => GetBranchesLoop,
    reply    => $reply,
    error    => $error,
    debug    => 0,
);

output_html_with_http_headers( $input, $cookie, $template->output );

sub fail {
    my @values = @_;
    foreach my $val ( @values ) {
        return 1 if (!$val or $val eq '');
    }
    return 0;
}

sub validate_borrower {
    # Perform cardnumber search.  If no results, perform surname search.
    # Return ( 0, undef ), ( 1, $brw ) or ( n, $brws )
    my $input = shift;
    my $borrowers = Koha::Borrowers->new;
    my ( $count, $brw );

    my $brws = $borrowers->search( { cardnumber => $input } );
    $count = $brws->count;
    if ( $count == 0 ) {
        $brws = $borrowers->search( { surname => $input } );
        $count = $brws->count;
        if ( $count == 1 ) {
            $brw = $brws->next;
        } elsif ( $count > 1 ) {
            $brw = $brws;       # found multiple results
        }
    } elsif ( $count == 1 ) {
        $brw = $brws->next;
    } else {
        $brw = $brws;           # found multiple results
    }

    return ( $count, $brw );
}
