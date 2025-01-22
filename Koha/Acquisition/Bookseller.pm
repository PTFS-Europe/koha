package Koha::Acquisition::Bookseller;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Acquisition::Bookseller::Aliases;
use Koha::Acquisition::Bookseller::Contacts;
use Koha::Acquisition::Bookseller::Interfaces;
use Koha::Acquisition::Bookseller::Issues;
use Koha::Subscriptions;

use C4::Contract qw( GetContracts );

use base qw( Koha::Object::Mixin::AdditionalFields Koha::Object Koha::Object::Limit::LibraryGroup );

=head1 NAME

Koha::Acquisition::Bookseller Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ($self) = @_;

    $self->set_lib_group_visibility() if $self->lib_group_visibility;
    $self = $self->SUPER::store();
    return $self;
}

=head3 baskets

    my $vendor  = Koha::Acquisition::Booksellers->find( $id );
    my @baskets = $vendor->baskets();

Returns the list of baskets for the vendor

=cut

sub baskets {
    my ( $self ) = @_;
    my $baskets_rs = $self->_result->aqbaskets;
    return Koha::Acquisition::Baskets->_new_from_dbic( $baskets_rs );
}

=head3 contacts

    my $vendor   = Koha::Acquisition::Booksellers->find( $id );
    my @contacts = $vendor->contacts();

Returns the list of contacts for the vendor

=cut

sub contacts {
    my ( $self, $contacts ) = @_;

    if ($contacts) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->contacts->delete;
                for my $contact (@$contacts) {
                    Koha::Acquisition::Bookseller::Contact->new(
                        {
                            %$contact,
                            booksellerid => $self->id,
                        }
                    )->store;
                }
            }
        );
    }

    my $rs = $self->_result->aqcontacts;
    return Koha::Acquisition::Bookseller::Contacts->_new_from_dbic($rs);
}


=head3 contracts

    my $vendor   = Koha::Acquisition::Booksellers->find( $id );
    my @contracts = $vendor->contracts();

Returns the list of contracts for the vendor

=cut

sub contracts {
    my ($self) = @_;
    return GetContracts(
        {
            booksellerid => $self->id,
        }
    );
}


=head3 subscriptions

    my $vendor        = Koha::Acquisition::Booksellers->find( $id );
    my $subscriptions = $vendor->subscriptions();

Returns the list of subscriptions for the vendor

=cut

sub subscriptions {
    my ($self) = @_;
    my $rs = $self->_result->subscriptions;
    return Koha::Subscriptions->_new_from_dbic($rs);
}

=head3 aliases

    my $aliases = $vendor->aliases

    $vendor->aliases([{ alias => 'one alias'}]);

=cut

sub aliases {
    my ($self, $aliases) = @_;

    if ($aliases) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->aliases->delete;
                for my $alias (@$aliases) {
                    $self->_result->add_to_aqbookseller_aliases($alias);
                }
            }
        );
    }

    my $rs = $self->_result->aqbookseller_aliases;
    return Koha::Acquisition::Bookseller::Aliases->_new_from_dbic( $rs );
}

=head3 interfaces

    my $interfaces = $vendor->interfaces

    $vendor->interfaces(\@interfaces);

=cut

sub interfaces {
    my ($self, $interfaces) = @_;

    if ($interfaces) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->interfaces->delete;
                for my $interface (@$interfaces) {
                    Koha::Acquisition::Bookseller::Interface->new(
                        {
                            %$interface,
                            vendor_id => $self->id,
                        }
                    )->store;
                }
            }
        );
    }

    my $rs = $self->_result->aqbookseller_interfaces;
    return Koha::Acquisition::Bookseller::Interfaces->_new_from_dbic( $rs );
}

=head3 issues

    my $issues = $vendor->issues

=cut

sub issues {
    my ($self) = @_;
    my $rs = $self->_result->aqbookseller_issues;
    return Koha::Acquisition::Bookseller::Issues->_new_from_dbic($rs);
}

=head3 invoices

    my $vendor  = Koha::Acquisition::Booksellers->find( $id );
    my @invoices = $vendor->invoices();

Returns the list of invoices for the vendor

=cut

sub invoices {
    my ($self) = @_;
    my $invoices_rs = $self->_result->aqinvoices;
    return Koha::Acquisition::Invoices->_new_from_dbic($invoices_rs);
}


=head3 to_api_mapping

This method returns the mapping for representing a Koha::Acquisition::Bookseller object
on the API.

=cut

sub to_api_mapping {
    return {
        listprice       => 'list_currency',
        invoiceprice    => 'invoice_currency',
        gstreg          => 'gst',
        listincgst      => 'list_includes_gst',
        invoiceincgst   => 'invoice_includes_gst'
    };
}


=head3 to_api

    my $json = $av->to_api;

Overloaded method that returns a JSON representation of the Koha::Acquisition::Bookseller object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $response  = $self->SUPER::to_api($params);
    my $overrides = {};

    if ( $self->interfaces ) {
        my $interfaces = $self->interfaces->as_list;
        my @updated_interfaces;
        foreach my $interface ( @{$interfaces} ) {
            $interface->password( $interface->plain_text_password );
            push @updated_interfaces, $interface->unblessed;
        }
        $overrides->{interfaces} = ( \@updated_interfaces );
    }

    return { %$response, %$overrides };
}


=head3 _library_group_visibility_parameters

Configure library group limits

=cut

sub _library_group_visibility_parameters {
    return {
        class             => "Aqbookseller",
        visibility_column => "lib_group_visibility",
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Aqbookseller';
}

1;
