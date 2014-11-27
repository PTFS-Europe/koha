package Koha::ILL::Request;

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
use base qw(Koha::Object);

=head1 NAME

Koha::ILL::Request - Koha ILL Request Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'IllRequest';
}

=head3 new

    my $illRequest = Koha::ILL::Request->new();

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

sub save {
    my ( $self ) = @_;

    my $save = Koha::Database->new()->schema()->resultset('IllRequest')
      ->create( ${$self}{status}->getFullStatus() );

    return $self;
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

    ${$self}{record} = ${Koha::ILL::AbstractILL->new()->search($uin)}[0];
    ${$self}{status} = Koha::ILL::Status->new();
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
        my $tmp = Koha::ILL::AbstractILL->new()->build($attributes);
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
