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
use Koha::Database;
use Koha::ILLRequest::Status;
use Koha::ILLRequest::Abstract;
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

=head3 save

    $illRequest->save();

Write $ILLREQUEST to the koha database (i.e. the ill_requests and
ill_request_attributes tables.

=cut

use Data::Dump qw( dump );
sub msg {
    open my $log_fh, '>>', '/home/alex/koha-dev/var/log/dump.log'
      or die "Could not open log: $!";
    print $log_fh @_;
    close $log_fh;
}

sub save {
    my ( $self ) = @_;
    # Build combined object as expected by dbic.
    # Retrieve Record
    my $full_rec = ${$self}{record}->getFullDetails();
    # create DBIC friendly attribute list
    my $attrs = [];
    foreach my $type ( keys $full_rec ) {
        #my $val = ( ${$full_rec}{$type}[1] or "" );
        push( @{$attrs}, { type => $type, value => ${$full_rec}{$type}[1] } );
    }
    # Get ill_request DBIC data
    my $save_obj = ${$self}{status}->getFields();
    # add attrs into ill_request
    ${$save_obj}{'ill_request_attributes'} = $attrs;
    msg(dump($save_obj), "\n");

    #save.
    my $save = Koha::Database->new()->schema()->resultset('IllRequest')
      ->create( $save_obj );

    return $save;
}

=head3 editStatus

    my $updatedRequest = $illRequest->editStatus($new_values);

Update $ILLREQUEST's Status with the hashref passed to EDITSTATUS.

=cut


sub editStatus {
    my ( $self, $new_values ) = @_;

    ${$self}{status}->update($new_values);

    msg(dump($self));

    return $self->save;
}

=head3 status

    my $status = $illRequest->status();

Return the Status component of the ILLREQUEST object $illRequest.  The Status
component provides information about the request for Koha.

=cut

sub status {
    my ( $self ) = @_;

    return $self->status;
}

=head3 summary

    my $summary = $illRequest->summary();

Return a data-structure ready for JSON or other format based processing and
display to the end-user.  It returns a composit of $self's Record and Status
`summary' methods.

=cut

sub getSummary {
    my ( $self ) = @_;
    my $record = ${$self}{record}->getSummary();
    my $status = ${$self}{status}->getSummary();
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
    my ( $self ) = @_;
    my $record = ${$self}{record}->getSummary();
    my $status = ${$self}{status}->getFullStatus();

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

=head3 seed_from_api

=cut

sub seed_from_api {
    my ( $self, $uin ) = @_;

    ${$self}{record} = ${Koha::ILLRequest::Abstract->new()->search($uin)}[0];
    ${$self}{status} = Koha::ILLRequest::Status->new();
    $self->save();        # save to DB.

    return $self;
}

=head3 seed_from_store

  Read a Record from the Koha Database. Here, we simply do a db
  attribute / IllRequest dump and feed that dump into Record
  structure: column_names => column values.

=cut

sub seed_from_store {
    my ( $self, $id ) = @_;

    my $result =
      Koha::Database->new()->schema()->resultset('IllRequest')->
        find( { id => $id },
              { join => 'ill_request_attributes', order_by => 'id' } );

    if ($result) {
        my $attributes = { $result->get_columns };
        my $linked = $result->ill_request_attributes;
        while ( my $attribute = $linked->next ) {
            $attributes->{ $attribute->get_column('type') } =
              $attribute->get_column('value');
        }
        # XXX: A bit Kludgy.
        my $tmp = Koha::ILLRequest::Abstract->new()->build($attributes);
        ${$self}{record} = ${$tmp}{record};
        ${$self}{status} = ${$tmp}{status};
        return $self;
    }

    return 0;
}

=head1 AUTHOR

Martin Renvoize <martin.renovize@ptfs-europe.com>

=cut

1;
