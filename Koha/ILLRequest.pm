package Koha::ILLRequest;

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
use Encode;
use Koha::Borrowers;
use Koha::Database;
use Koha::Email;
use Koha::ILLRequest::Status;
use Koha::ILLRequest::Abstract;
use Mail::Sendmail;
use base qw(Koha::Object);

=head1 NAME

Koha::ILLRequest - Koha ILL Request Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'IllRequest';
}

=head3 new

    my $illRequest = Koha::ILLRequest->new();

Create a new $illRequest.

=cut

sub new {
    my ( $class ) = @_;
    my $self = {};

    bless $self, $class;

    return $self;
}

=head3 delete

    my $ok = $illRequest->delete;

Wrapper around dbix::class' delete.

=cut

sub delete {
    my ( $self ) = @_;

    my $result_set = Koha::Database->new->schema->resultset('IllRequest');
    my $rq = $result_set->find( $self->status->getProperty('id') );
    my $related = $result_set->search_related(
        'ill_request_attributes', { req_id => $rq->id }
    );

    my $result = $rq->delete if $related->delete_all;
    return $result || 0;
}

=head3 save

    $illRequest->save();

Write $ILLREQUEST to the koha database (i.e. the ill_requests and
ill_request_attributes tables.

=cut

sub save {
    my ( $self, $field ) = @_;
    # Build combined object as expected by dbic.
    # Get ill_request DBIC data
    my $save_obj = $self->status->getFields;
    my $result_set = Koha::Database->new->schema;
    # If this is the first save, we must merge in the Record.
    if ( $save_obj->{id} and $field ) {
        # We have a specific field in the Record that has been updated and
        # which must be saved.
        $result_set = $result_set->resultset('IllRequestAttribute');
        my $attribute = $result_set->find(
            ( $save_obj->{id}, 'primary_' . $field )
        );
        $attribute->value( $self->record->property($field) );
        my $save = $attribute->update;
    } else {
        $result_set = $result_set->resultset('IllRequest');
        if ( !$save_obj->{id} ) {
            # Retrieve Record
            my $full_rec = $self->record->getFullDetails;
            # create DBIC friendly attribute list
            my @attrs = ();
            while ( my ( $type, $value ) = each %{$full_rec} ) {
                push @attrs, { type => $type, value => ${$value}[1] };
            }
            # List of additional, non-automatic "Record" fields.  These are
            # additional fields used directly by the Koha ILL interface.
            foreach ( qw/ access_url cost notes_opac notes_staff order_id/ ) {
                push @attrs, { type => 'primary_' . $_, value => '' };
            }
            # add attrs into ill_request
            $save_obj->{'ill_request_attributes'} = \@attrs;
        }
        my $save = $result_set->update_or_create( $save_obj );
        $self->status->{id} = $save->id unless $save_obj->{id};
    }
    return $self;
}

=head3 checkAvailability

    my $checkAvailability = $illRequest->checkAvailability();

Ask our Record to connect to its source (API) to check the availability for
this Request, then request the latest prices information and compile a list of
prices for the request.

Currently this is not implemented. A request such as this would involve 1 + n
API requests, n being the number of format/speed/quality combinations.

Perhaps a preferable approach would be to fire additional requests for
calculatePrice through AJAX?

=cut

sub checkAvailability {
    my ( $self, $testData ) = @_;
    my $availability =
      ${$self}{record}->checkAvailability(${$testData}{availability});
    my $prices = ${$self}{record}->checkAvailability(${$testData}{prices});

}

=head3 calculatePrice

    my $calculateP = $illRequest->calculatePrice($data);

Take $DATA, a hashref containing a FORMAT and PRICE key with the respective
API IDs as values, and return the price for that particular request.

=cut


sub calculatePrice {
    my ( $self, $data, $testData ) = @_;

    # testData is used for unit testing only
    my $prices = ${$self}{record}->checkPrices($testData);
    my $xpath = '//format[@id="' . ${$data}{format} . '"]/price[@speed="' .
      ${$data}{speed} . '" and @quality="' . ${$data}{quality} . '"]';
    # We have format from before; now we need to retrieve price for display,
    # as well as service id for eventual request.
    my $price = $prices->findnodes($xpath);
    if (@{$price} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    my $exact = ${$price}[0];
    my $service = $exact->parentNode->parentNode;

    # Currently hard-coded values rather than read from config.
    my $result = {
        currency        => [ "Currency", $prices->currency ],
        region          => [ "Region", $prices->region ],
        copyrightVat    => [ "CopyrightVat", $prices->copyrightVat ],
        loanRenewalCost => [ "Loan Renewal Cost", $prices->loanRenewalCost ],
        price           => [ "Price", $exact->textContent ],
        service         => [ "Service", $service->{id} ],
    };

    return $result;
}

=head3 checkSimpleAvailability

    my $justAvailability = $illRequest->checkSimpleAvailability();

Ask our Record to connect to its source (API) to check the availability for
this Request.

=cut

sub checkSimpleAvailability {
    my ( $self, $testData ) = @_;
    my $availability = ${$self}{record}->checkAvailability($testData);
    # We have a status message from the API.
    return $availability
        if ( 'HASH' eq ref $availability and $availability->{status} );
    my @formats;
    foreach my $format (@{$availability->formats}) {
        my @speeds;
        foreach my $speed (@{$format->speeds}) {
            push @speeds,
              {
               speed => [ "Speed", $speed->textContent ],
               key => [ "Key", $speed->key ],
              };
        }
        my @qualities;
        foreach my $quality (@{$format->qualities}) {
            push @qualities,
              {
               quality => [ "Quality", $quality->textContent ],
               key => [ "Key", $quality->key ],
              };
        }

        push @formats,
          {
           format    => [ "Format", $format->deliveryFormat->textContent ],
           key       => [ "Key", $format->deliveryFormat->key ],
           speeds    => [ "Speeds", \@speeds ],
           qualities => [ "Qualities", \@qualities ],
          };
    }

    my $result =
      {
       copyrightFee => [ "Copyright fee", $availability->copyrightFee ],
       availableImmediately => [ "Available immediately?",
                                 $availability->availableImmediately ],
       formats => [ "Formats", \@formats ],
      };

    return $result;
}

=head3 editStatus

    my $updatedRequest = $illRequest->editStatus($new_values);

Update $ILLREQUEST's Status with the hashref passed to EDITSTATUS.

=cut

sub editStatus {
    my ( $self, $new_values ) = @_;

    if ( $new_values->{borrower} ) {
        my $brw = _borrower_from_number($new_values->{borrower}, 'crd');
        $new_values->{borrowernumber} = $brw->borrowernumber;
        delete $new_values->{borrower};
    }
    $self->status->update($new_values);
    my $upd = $self->record->update($new_values);
    foreach ( @{$upd} ) {
        $self->save($_);
    }

    return 1
      if $self->save;
}

=head3 getStatus

    my $statusMsg = $illRequest->getStatus;

Return $ILLREQUEST's current status (the status message, NOT the status
object).

=cut

sub getStatus {
    my ( $self ) = @_;

    return $self->status->getProperty('status');
}

=head2 primary accessors

Primary accessors are fields stored in the ill_request_attributes table, but
which API independent.  They are assumed to always exist -- though the API may
well not fill in these values.

The most important primary accessor is order_id: this is the id associated
with a request in the API in use.  It is used to perform further operations
for this request against the API.

=cut

=head3 _prim_logic

    my $primary_accessor = $illRequest->_prim_logic('name');

Helper to factor out logic common to all primary accessor getters/setters.

=cut

sub _prim_logic {
    my ( $self, $name ) = @_;

    return sub {
        my ( $params ) = @_;
        if ( $params ) {
            my $result = $self->record->property( $name, $params );
            if ( $self->save($name) ) {
                return $result;
            } else {
                return 0;
            }
            return $self;
        } else {
            return $self->record->property( $name );
        }
    }
}

=head3 order_id

    my $orderID = $illRequest->order_id;
    # or
    my $newOrderID = $illRequest->order_id('newOrderID');

Helper function to access or set the order_id associated with this request.

=cut

sub order_id {
    my ( $self, $id ) = @_;     # for now we assume $id is a string.
    return &{$self->_prim_logic('order_id')}($id);
}

=head3 access_url

    my $url = $illRequest->access_url;
    # or
    my $new_url = $illRequest->access_url('new_url');

Helper function to access or set the access_url associated with this request.

=cut

sub access_url {
    my ( $self, $url ) = @_;
    return &{$self->_prim_logic('access_url')}($url);
}

=head3 cost

    my $cost = $illRequest->cost;
    # or
    my $new_cost = $illRequest->cost('new_cost');

Helper function to access or set the cost associated with this request.

=cut

sub cost {
    my ( $self, $cost ) = @_;
    return &{$self->_prim_logic('cost')}($cost);
}

=head3 opac_notes

    my $opac_notes = $illRequest->opac_notes;
    # or
    my $new_opac_notes = $illRequest->opac_notes('new_opac_notes');

Helper function to access or set the opac_notes associated with this request.

=cut

sub opac_notes {
    my ( $self, $opac_notes ) = @_;
    return &{$self->_prim_logic('notes_opac')}($opac_notes);
}

=head3 staff_notes

    my $staff_notes = $illRequest->staff_notes;
    # or
    my $new_staff_notes = $illRequest->staff_notes('new_staff_notes');

Helper function to access or set the staff_notes associated with this request.

=cut

sub staff_notes {
    my ( $self, $staff_notes ) = @_;
    return &{$self->_prim_logic('notes_staff')}($staff_notes);
}

=head3 status

    my $status = $illRequest->status;

Return the Status component of the ILLREQUEST object $illRequest.  The Status
component provides information about the request for Koha.

=cut

sub status {
    my ( $self ) = @_;

    return $self->{status};
}

=head3 record

    my $record = $illRequest->record();

Return the Record component of the ILLREQUEST objet $ILLREQUEST.  The Record
component provides bibliographic details as retrieved from the API.

=cut

sub record {
    my ( $self ) = @_;
    return $self->{record};
}

=head3 summary

    my $summary = $illRequest->summary();

Return a data-structure ready for JSON or other format based processing and
display to the end-user.  It returns a composit of $self's Record and Status
`summary' methods.

=cut

sub getSummary {
    my ( $self, $params ) = @_;
    my $record = ${$self}{record}->getSummary($params);
    my $status = ${$self}{status}->getSummary($params);
    my %summary = (%{$record}, %{$status});

    return \%summary;
}

=head3 fullRequest

    my $fullRequest = $illRequest->getFullRequest();

Return a data-structure ready for JSON or other format based processing and
display to the end-user.  It returns a composit of $self's Record and Status
`fullDetails' methods.

=cut

sub getFullDetails {
    my ( $self ) = @_;
    my $record = ${$self}{record}->getFullDetails();
    my $status = ${$self}{status}->getFullStatus();
    my %summary = (%{$record}, %{$status});

    return \%summary;
}

=head3 getForEditing

    my $partialRequest = $illRequest->getForEditing();

Return a data-structure ready-for-JSON-or-other-format conversion and
display. The data-structure will be a hashref of 2, with the first entry
consisting of a summary of the Record, and the second entry consisting of the
full Status details.

The former is for display and should not be edited by hand.  The latter can be edited.

=cut

sub getForEditing {
    my ( $self, $params ) = @_;
    my $record = $self->record->getFullDetails($params);
    my $status = $self->status->getFullStatus($params);

    return [ $record, $status ];
}

=head3 update

    my $status = $illRequest->update($operation);

Return the new Status object contained by $self, following on from our attempt
to perform $OPERATION on $self.

$illRequest will update the database with the result of $OPERATION.

=cut

sub update {
    my ( $self, $operation ) = @_;

    # XXX: perform operation, then;
    $self->save();

    return $self->status();
}

sub _seed_for_test {
    my ($self, $recordData) = @_;
    ${$self}{record} =
      Koha::ILLRequest::Record->new(Koha::ILLRequest::Config->new());
    ${$self}{record}->create_from_xml($recordData);
    ${$self}{status} = Koha::ILLRequest::Status->new();
    return $self;
}

=head3 seed

    my $seed = $illRequest->seed();

A generic seeding procedure, taking a hashref as an argument.  Depending on
the keys of the hashref we defer to seed_from_api or seed_from_store.

=cut

sub seed {
    my ( $self, $opts ) = @_;

    my $rq;
    if ( $opts->{id} ) {
        $rq = $self->_seed_from_store( $opts );
    } elsif ( $opts->{uin} ) {
        $rq = $self->_seed_from_api( $opts );
    } else {
        $rq = 0
    }

    return $rq;
}

=head3 _seed_from_api

=cut

sub _seed_from_api {
    my ( $self, $opts ) = @_;

    $self->{record} = ${Koha::ILLRequest::Abstract->new
          ->search($opts->{uin})}[0];
    $self->{status} = Koha::ILLRequest::Status->new( {
              reqtype   => $self->{record}->getProperty('type'),
              borrower  => $opts->{borrower},
              branch    => $opts->{branch},
              permitted => $opts->{permitted},
             }
           );
    $self->save();        # save to DB.

    return $self;
}

=head3 _seed_from_store

  Read a Record from the Koha Database. Here, we simply do a db
  attribute / IllRequest dump and feed that dump into Record
  structure: column_names => column values.

=cut

sub _seed_from_store {
    my ( $self, $opts ) = @_;

    my $result_set = Koha::Database->new->schema->resultset('IllRequest');
    my $result = $result_set->find( $opts->{id} );

    if ($result) {
        my $linked = $result_set->search_related(
            'ill_request_attributes', { req_id => $opts->{id} }
        );
        my $attributes = { $result->get_columns };
        while ( my $attribute = $linked->next ) {
            $attributes->{ $attribute->get_column('type') } =
              $attribute->get_column('value');
        }
        $attributes->{borrower}
            = _borrower_from_number($attributes->{borrowernumber}, 'brw');
        # XXX: A bit Kludgy.
        my $tmp = Koha::ILLRequest::Abstract->new->build($attributes);
        $self->{record} = $tmp->{record};
        $self->{status} = $tmp->{status};
        return $self;
    }

    return 0;
}

=head3 requires_moderation

    my $status = $illRequest->requires_moderation;

Return the name of the status if moderation by staff is required; or 0
otherwise.

=cut

sub requires_moderation {
    my ( $self ) = @_;
    my $status = $self->status->getProperty('status');
    my $require_moderation = {
        'Cancellation Requested' => 'Cancellation Requested',
    };
    return $require_moderation->{$status};
}

=head3 place_request

    my ( $result, $request ) = $illRequest->place_request();

Create an API request from $PARAMS.  If we are successful, return 0 and our
request object; else return 1 and our request object.

=cut

sub place_request {
    my ( $self, $params ) =@_;
    my $brw = $self->status->getProperty('borrower');
    my $branch_code = $self->status->getProperty('branch');
    my $brw_cat     = $brw->categorycode;

    my $details = $params->{details}
        || Koha::ILLRequest::Abstract->new->getDefaultFormat( {
            brw_cat => $brw_cat,
            branch  => $branch_code,
        } );

    my $success = Koha::ILLRequest::Abstract->new->request(
        {
            branch      => $self->status->getProperty('branch'),
            patron      => $brw,
            transaction => $details,
            record      => $self->record,
            # FIXME: we'll need to add prefix here
            reference   => $self->status->getProperty('id'),
        }
    );

    return ( $success, $self )
        if ( 'HASH' eq ref $success and $success->{status} );

    # FIXME: these are currently hard-coded to BLDSS
    $self->order_id($success->result->newOrder->orderline);
    $self->cost($success->result->newOrder->totalCost);
    $self->access_url($success->result->newOrder->downloadUrl);

    $self->editStatus( { status => "Requested" } );
    return ( 1, $self );
}

=head3 cancel_request

    my $status = $illRequest->cancel_request;

Use the interface to attempt to cancel a request.

=cut

sub cancel_request {
    my ( $self ) = @_;
    my $result = Koha::ILLRequest::Abstract->new
        ->cancel_request( { order_id => $self->order_id } );
    if ( 'cancel_success' eq $result->{status} ) {
        # Succes, change status, remove order_id.
        $self->editStatus( { status => "Request reverted" } );
        $self->order_id("UNSET");
    }
    return ( $result, $self );
}

=head3 status_request

    my $status_request = $illRequest->status_request;

Use the interface to retrieve API details of the currently placed request.

=cut

sub status_request {
    my ( $self ) = @_;
    my $result = Koha::ILLRequest::Abstract->new
        ->status( { order_id => $self->order_id } );

    return ( $result, $self );
}

=head3 place_generic_request

    my ( $result, $email ) = $illRequest->place_generic_request($params);

Create an email from $PARAMS and submit it.  If we are successful, return 1
and the email summary.  If not, then return 0 and the email summary.

=cut

sub place_generic_request {
    my ( $self, $params ) = @_;

    my $message = Koha::Email->new;
    $params->{to} = join("; ", @{$params->{to}});
    if ( !$params->{from} || $params->{from} eq '' ) {
        die "No originator for email: ", $params->{from};
    }
    if ( !$params->{replyto} || $params->{replyto} eq '') {
        $params->{replyto} = $params->{from};
    }
    if ( !$params->{sender} || $params->{sender} eq '' ) {
        $params->{sender} = $params->{from};
    }
    my %mail = $message->create_message_headers(
        {
            to          => $params->{to},
            from        => $params->{from},
            replyto     => $params->{replyto},
            sender      => $params->{sender},
            subject     => Encode::encode( "utf8", $params->{subject} ),
            message     => Encode::encode( "utf8", $params->{message} ),
            contenttype => 'text/plain; charset="utf8"',
        }
    );

    my $result = sendmail(%mail);
    if ( $result ) {
        $self->editStatus( { status => "Requested by Email" } );
        return (1, $params);
    } else {
        carp($Mail::Sendmail::error);
        return (0, $params);
    }

}

=head3 prepare_generic_request

    my $emailTemplate = $illRequest->prepare_generic_request;

Return a hashref containing 'subject'and 'body' for an email.

=cut

sub prepare_generic_request {
    my ( $self ) = @_;


    my $draft->{subject} = "ILL Request";
    $draft->{body} = <<EOF;
Dear Sir/Madam,

    We would like to request an interlibrary loan for title matching the
following description:

EOF

    my $details = $self->record->getFullDetails;
    while (my ($key, $values) = each $details) {
        if (${$values}[1]) {
            $draft->{body} .= "  - " . ${$values}[0]
                . ": " . ${$values}[1]. "\n";
        }
    }

    $draft->{body} .= <<EOF;

Please let us know if you are able to supply this to us.

Kind Regards
EOF

    return $draft;
}

=head3 _borrower_from_number

    my $_borrower_from_number = $illRequest->_borrower_from_number();

Return a borrower from the given card or borrower $NUMBER.  The strategy for
resolution depends on $strategy:
  - 'crd' means try only cardnumber, error otherwise.
  - 'brw' means try only borrowernumber, error otherwise.
  - else: try both and return the first match.

=cut

sub _borrower_from_number {
    my ( $number, $strategy ) = @_;

    my $borrowers = Koha::Borrowers->new;
    my $brws;
    if ( 'crd' eq $strategy ) {
        $brws = $borrowers->search( { cardnumber => $number } );
    } elsif ( 'brw' eq $strategy ) {
        $brws = $borrowers->search( { borrowernumber => $number } );
    } else {
        $brws = $borrowers->search( { borrowernumber => $number } );
        $brws = $borrowers->search( { cardnumber => $number } )
            unless ( $brws->count == 1 );
    }

    die "Invalid borrower: ($number)"
        unless ( $brws->count == 1 ); # brw fetch did not work
    # we should have a unique brw.
    return $brws->next;
}

=head1 AUTHOR

Martin Renvoize <martin.renovize@ptfs-europe.com>
Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
