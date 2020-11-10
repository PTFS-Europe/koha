package Koha::Acquisition::Basket;

# Copyright 2017 Aleisha Amohia <aleisha@catalyst.net.nz>
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

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Acquisition::BasketGroups;

use base qw( Koha::Object Koha::Object::Mixin::AdditionalFields );

=head1 NAME

Koha::Acquisition::Basket - Koha Basket Object class

=head1 API

=head2 Class Methods

=cut

=head3 bookseller

Returns the vendor

=cut

sub bookseller {
    my ($self) = @_;
    my $bookseller_rs = $self->_result->booksellerid;
    return Koha::Acquisition::Bookseller->_new_from_dbic( $bookseller_rs );
}

=head3 basket_group

Returns the basket group associated to this basket

=cut

sub basket_group {
    my ($self) = @_;
    my $basket_group_rs = $self->_result->basketgroupid;
    return unless $basket_group_rs;
    return Koha::Acquisition::BasketGroup->_new_from_dbic( $basket_group_rs );
}

=head3 effective_create_items

Returns C<create_items> for this basket, falling back to C<AcqCreateItem> if unset.

=cut

sub effective_create_items {
    my ( $self ) = @_;

    return $self->create_items || C4::Context->preference('AcqCreateItem');
}

=head3 estimated_delivery_date

my $estimated_delivery_date = $basket->estimated_delivery_date;

Return the estimated delivery date for this basket.

It is calculated adding the delivery time of the vendor to the close date of this basket.

Return implicit undef if the basket is not closed, or the vendor does not have a delivery time.

=cut

sub estimated_delivery_date {
    my ( $self ) = @_;
    return unless $self->closedate and $self->bookseller->deliverytime;
    return dt_from_string($self->closedate)->add( days => $self->bookseller->deliverytime);
}

=head3 late_since_days

my $number_of_days_late = $basket->late_since_days;

Return the number of days the basket is late.

Return implicit undef if the basket is not closed.

=cut

sub late_since_days {
    my ( $self ) = @_;
    return unless $self->closedate;
    return dt_from_string->delta_days(dt_from_string($self->closedate))->delta_days();
}

=head3 authorizer

my $authorizer = $basket->authorizer;

Returns the patron who authorized/created this basket.

=cut

sub authorizer {
    my ($self) = @_;
    # FIXME We should use a DBIC rs, but the FK is missing
    return unless $self->authorisedby;
    return scalar Koha::Patrons->find($self->authorisedby);
}


=head3 to_api

    my $json = $basket->to_api;

Overloaded method that returns a JSON representation of the Koha::Acquisition::Basket object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $json = $self->SUPER::to_api( $params );

    $json->{closed} = ( $self->closedate )
                                    ? Mojo::JSON->true
                                    : Mojo::JSON->false;

    return $json;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Acquisition::Basket object
on the API.

=cut

sub to_api_mapping {
    return {
        basketno                => 'basket_id',
        basketname              => 'name',
        booksellernote          => 'vendor_note',
        contractnumber          => 'contract_id',
        creationdate            => 'creation_date',
        closedate               => 'close_date',
        booksellerid            => 'vendor_id',
        authorisedby            => 'creator_id',
        booksellerinvoicenumber => undef,
        basketgroupid           => 'basket_group_id',
        deliveryplace           => 'delivery_library_id',
        billingplace            => 'billing_library_id',
        branch                  => 'library_id',
        is_standing             => 'standing'
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Aqbasket';
}

=head1 AUTHOR

Aleisha Amohia <aleisha@catalyst.net.nz>
Catalyst IT

=cut

1;
