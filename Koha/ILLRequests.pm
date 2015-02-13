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

    my $Records = $illRequests->search_api($query);

Perform a search against the defined API, returning an array of RECORDs, which
can be used for output to the end-user.  For placing the request, the
`$illRequests->request($uin)' method should be used.

=cut

sub search_api {
    my ( $self, $query, $opts ) = @_;
    my $summaries;

    my $records = Koha::ILLRequest::Abstract->new()->search($query, $opts);
    foreach my $recs ( @{$records} ) {
        push @{$summaries}, $recs->getSummary();
    }
    return $summaries;
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

    my $brws = Koha::Borrowers->new->search( {
        cardnumber => $opts->{borrower},
    } );

    if ( $brws->count == 1 ) {
        $opts->{borrower} = $brws->next->borrowernumber;
        my $illRequest = Koha::ILLRequest->new()->seed($opts);
        return $illRequest;
    } else {
        return 0;
    }

}

=head3 retrieve_ill_requests

    my $illRequest = $illRequests->retrieve_ill_requests();
    -OR-
    my $illRequest = $illRequests->retrieve_ill_requests($borrowernumber);

Retrieve either all ILLREQUESTs currently stored in the db, or only
those attached to $BORROWERNUMBER.

Returns a reference to an array of ILLREQUESTs.

=cut

sub retrieve_ill_requests {
    my ( $self, $borrowernumber ) = @_;
    my $result;

    if ($borrowernumber) {
        $result = Koha::Database->new()->schema()->resultset('IllRequest')
          ->search( { borrowernumber => $borrowernumber } );
    } else {
        $result = Koha::Database->new()->schema()->resultset('IllRequest')
          ->search( { id => { 'like', '%' } } );
    }

    my $illRequests = [];
    while ( my $row = $result->next ) {
        push @{$illRequests},
          Koha::ILLRequest->new()->seed( { id => $row->id } );
    }

    return $illRequests;
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
