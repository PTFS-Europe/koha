package Koha::ILLRequests;

# Copyright PTFS Europe 2014
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
use Carp;

use Koha::Borrowers;
use Koha::Database;
use Koha::ILLRequest;
use Koha::ILLRequest::Abstract;
use Koha::ILLRequest::Status;
use URI::Escape;

use base qw(Koha::Objects);

=head1 NAME

Koha::ILLRequests - Koha ILL Requests Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'IllRequest';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ILLRequest';
}

=head3 new

    my $illRequests = Koha::ILLRequests->new();

Create an ILLREQUESTS object, a singleton through which we can interact with
ILLREQUEST objects stored in the database or search for ILL candidates at API
backends.

=cut

sub new {
    my ( $class ) = @_;
    my $self = {};

    bless $self, $class;

    return $self;
}

=head3 search_api

    my $Records = $illRequests->search_api($opts);

Perform a search against the defined API, returning an array of RECORDs, which
can be used for output to the end-user.  For placing the request, the
`$illRequests->request($uin)' method should be used.

=cut

sub search_api {
    my ( $self, $opts ) = @_;
    my $records = Koha::ILLRequest::Abstract->new
        ->search($opts->{keywords}, $opts);
    $self->{opts} = $opts;
    $self->{opts}->{max_results} = $opts->{max_results} || 10;
    $self->{opts}->{start_rec}   = $opts->{start_rec}   || 1;
    $self->{search_results} = $records;

    if (!$records) {
        $self->{search_results} = [];
        return 0;
    }

    my $summaries = [];
    foreach my $recs ( @{$records} ) {
        push @{$summaries}, $recs->getSummary();
    }
    return $summaries;
}

=head3 get_pagers

    my $pagers = $requests->get_pagers(
        { next => $base_url . "/next=", previous => $base_url . "/prev=" });

When passed a hashref containing keys next and/or previous, return a hashref
with keys previous and next, set to the concatenation of the values of the
respective keys passed in and the appropriate starting record for
next/previous.

If next or previous make no sense on the result list, return 0 as the value
for each key respectively.

=cut

sub get_pagers {
    my ( $self, $pagers ) = @_;
    die "No search has been performed against the API yet"
        unless $self->{opts};
    my $max_results = $self->{opts}->{max_results};
    my $results  = @{$self->{search_results}};
    my $current  = $self->{opts}->{start_rec};
    my ( $next, $previous, $position ) = ( 0, 0, 0 );

    if ( $pagers->{next} ) {
        $position = $current + $results;
        $next = $pagers->{next} . $position
            if ( $results == $max_results );
    }
    if ( $pagers->{previous} ) {
        $position = $current - $results;
        $previous = $pagers->{previous} . $position
            if ( $position >= 1 );
    }

    return { previous => $previous, next => $next };
}

=head3 get_search_string

    my $search_string = $requests->get_search_string();

Return the search options used for the last search in a display friendly way.

=cut

sub get_search_string {
    my ( $self ) = @_;
    die "No search has been performed against the API yet"
        unless $self->{opts};
    my $userstring = "";
    my @querystring = ();
    my $opts = $self->{opts};
    while ( my ($type, $value) = each $opts ) {
        $userstring .= "[" . join(": ", $type, $value) . "]";
        push @querystring, join("=", $type, uri_escape($value));
    }
    my $strings = {
        userstring  => $userstring,
        querystring => join("&", @querystring),
    };
    return $strings;
}

=head3 request

    my $illRequest = $illRequests->request($uin)

Place a request on the item identified in the API by $UIN.  Whether an actual
request is placed, or whether we add the request to the 'pending for review'
queue depends on various sysprefs and configuration.

Either way we will return an ILLREQUEST object containing a Record with
details for that item in the API and a Status, which details the status of
this request.

=cut

sub request {
    my ( $self, $opts ) = @_;

    # $opts->{borrower} is either a cardnumber or a borrowernumber.
    my $borrowers = Koha::Borrowers->new;
    my $brws = $borrowers->search( { borrowernumber => $opts->{borrower} } );
    $brws = $borrowers->search( {cardnumber => $opts->{borrower} } )
        unless ( $brws->count == 1 );

    die "Invalid borrower"
        unless ( $brws->count == 1 ); # brw fetch did not work

    # we have a brw.
    my $brw       = $brws->next;
    my $permitted = $self->check_limits(
        { borrower => $brw }, { branch => $opts->{branch} }
    );
    $opts->{borrower} = $brw->borrowernumber;
    $opts->{permitted} = $permitted;
    my $request = Koha::ILLRequest->new->seed($opts);

    if ( C4::Context->preference("UnmediatedILL") && $permitted ) {
        # FIXME: Also carry out privilege checks
        my ( $result, $new_rq ) =
            $request->place_request;
        if ( $result ) {
            return $new_rq;
        } else {
            die "Placing the request failed.";
        }
    } else {
        return $request;
    }
}

=head3 retrieve_ill_requests

    my $illRequests = $illRequests->retrieve_ill_requests();
    -OR-
    my $illRequests = $illRequests->retrieve_ill_requests($borrowernumber);
    -OR-
    my $illRequests = $illRequests->retrieve_ill_requests({column => value});

Retrieve either all ILLREQUESTs currently stored in the db, or only those
attached to $BORROWERNUMBER.  Finally, if a hashref is passed to this method
then we performa a search against the db using that hashref as the search
criteria.

Returns a reference to an array of ILLREQUESTs.

=cut

sub retrieve_ill_requests {
    my ( $self, $target ) = @_;
    my $result;

    if ( ( $target && ref $target eq 'HASH' ) or !$target ) {
        $result = $self->_retrieve_requests($target)
    } else {
        $result = $self->_retrieve_requests( { borrowernumber => $target } )
    }

    my $illRequests = [];
    while ( my $row = $result->next ) {
        push @{$illRequests},
          Koha::ILLRequest->new->seed( { id => $row->id } );
    }

    return $illRequests;
}

=head3 _retrieve_requests

    my $requests = $illRequests->_retrieve_requests( $params );

New abstraction helper to simply fetch arbitrary selection of requests.
$PARAMS should be a hashref containing valid resultset search criteria.

=cut

sub _retrieve_requests {
    my ( $self, $params ) = @_;
    return Koha::Database->new->schema->resultset('IllRequest')
        ->search($params);
}

=head3 check_limits

    my $ok = $illRequests->check_limits( {
        borrower   => $borrower,
        branchcode => 'branchcode' | undef,
    } );

Given $PARAMS, a hashref containing a $borrower object and a $branchcode,
see whether we are still able to place ILLs.

LimitRules are derived from koha-conf.xml:
 + default limit counts, and counting method
 + branch specific limit counts & counting method
 + borrower category specific limit counts & counting method
 + err on the side of caution: a counting fail will cause fail, even if
   the other counts passes.

=cut

sub check_limits {
    my ( $self, $params ) = @_;
    my $borrower          = $params->{borrower};
    my $branchcode        = $params->{branch} || $borrower->branchcode;

    # Establish rules
    my $abstract = Koha::ILLRequest::Abstract->new;
    my ( $branch_rules, $brw_rules ) = (
        $abstract->getLimits( {
            type => 'branch',
            value => $branchcode
        } ),
        $abstract->getLimits( {
            type => 'brw_cat',
            value => $borrower->categorycode,
        } ),
    );
    # Almost there, but category code didn't quite work.
    my ( $branch_limit, $brw_limit )
        = ( $branch_rules->{count}, $brw_rules->{count} );
    my ( $branch_count, $brw_count ) = (
        $self->_limit_counter(
            $branch_rules->{method}, { branch => $branchcode }
        ),
        $self->_limit_counter(
            $brw_rules->{method}, { borrowernumber => $borrower->borrowernumber }
        ),
    );

    # Compare and return
    # A limit of -1 means no limit exists.
    if ( ( $branch_limit != -1 && $branch_limit <= $branch_count )
             || ( $brw_limit != -1 && $brw_limit <= $brw_count ) ) {
        return 0;
    } else {
        return 1;
    }
}

sub _limit_counter {
    my ( $self, $method, $target ) = @_;

    # Establish parameters of counts
    my $where;
    if ($method eq 'annual') {
        $where = { "year(placement_date)" => \" = year(now())" };
    } else {                    # assume 'active'
        # FIXME: This status list is ugly. There should be a method in config
        # to return these.
        $where = { status => { -not_in => [ 'Queued', 'Completed' ] } };
    }

    # Create resultset
    my $resultset = $self->_retrieve_requests( { %{$target}, %{$where} } );

    # Fetch counts
    return $resultset->count;
}

=head3 retrieve_ill_request

    my $illRequest = $illRequests->retrieve_ill_request($illRequestId);

Retrieve the ILLREQUEST identified by $ILLREQUESTID.

=cut

sub retrieve_ill_request {
    my ( $self, $illRequestId ) = @_;

    my $request = Koha::ILLRequest->new()->seed( { id => $illRequestId } );
    if ( $request ) {
        return [ $request ];
    } else {
        return [];
    }
}

=head1 AUTHOR

Martin Renvoize <martin.renovize@ptfs-europe.com>

=cut

1;
