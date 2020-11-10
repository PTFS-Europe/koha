package Koha::REST::V1::Checkouts;

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

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

use C4::Auth qw( haspermission );
use C4::Context;
use C4::Circulation;
use Koha::Checkouts;
use Koha::IssuingRules;
use Koha::Old::Checkouts;

use Try::Tiny;

=head1 NAME

Koha::REST::V1::Checkout

=head1 API

=head2 Methods

=head3 list

List Koha::Checkout objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;
    my $checked_in = $c->validation->param('checked_in');
    try {
        my $checkouts_set;
        if ( $checked_in ) {
            $checkouts_set = Koha::Old::Checkouts->new;
        } else {
            $checkouts_set = Koha::Checkouts->new;
        }
        my $checkouts = $c->objects->search( $checkouts_set, \&_to_model, \&_to_api );
        return $c->render( status => 200, openapi => $checkouts );
    } catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(
                status => 500,
                openapi => { error => $_->{msg} }
            );
        } else {
            return $c->render(
                status => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

=head3 get

get one checkout

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $checkout_id = $c->validation->param('checkout_id');
    my $checkout = Koha::Checkouts->find( $checkout_id );
    $checkout = Koha::Old::Checkouts->find( $checkout_id )
        unless ($checkout);

    unless ($checkout) {
        return $c->render(
            status => 404,
            openapi => { error => "Checkout doesn't exist" }
        );
    }

    return $c->render(
        status  => 200,
        openapi => $checkout->to_api
    );
}

=head3 renew

Renew a checkout

=cut

sub renew {
    my $c = shift->openapi->valid_input or return;

    my $checkout_id = $c->validation->param('checkout_id');
    my $seen = $c->validation->param('seen') || 1;
    my $checkout = Koha::Checkouts->find( $checkout_id );

    unless ($checkout) {
        return $c->render(
            status => 404,
            openapi => { error => "Checkout doesn't exist" }
        );
    }

    my $borrowernumber = $checkout->borrowernumber;
    my $itemnumber = $checkout->itemnumber;

    my ($can_renew, $error) = C4::Circulation::CanBookBeRenewed(
        $borrowernumber, $itemnumber);

    if (!$can_renew) {
        return $c->render(
            status => 403,
            openapi => { error => "Renewal not authorized ($error)" }
        );
    }

    AddRenewal($borrowernumber, $itemnumber, $checkout->branchcode, undef, undef, $seen);
    $checkout = Koha::Checkouts->find($checkout_id);

    $c->res->headers->location( $c->req->url->to_string );
    return $c->render(
        status  => 201,
        openapi => $checkout->to_api
    );
}

=head3 allows_renewal

Checks if the checkout could be renewed and return the related information.

=cut

sub allows_renewal {
    my $c = shift->openapi->valid_input or return;

    my $checkout_id = $c->validation->param('checkout_id');
    my $checkout = Koha::Checkouts->find( $checkout_id );

    unless ($checkout) {
        return $c->render(
            status => 404,
            openapi => { error => "Checkout doesn't exist" }
        );
    }

    my ($can_renew, $error) = C4::Circulation::CanBookBeRenewed(
        $checkout->borrowernumber, $checkout->itemnumber);

    my $renewable = Mojo::JSON->false;
    $renewable = Mojo::JSON->true if $can_renew;

    my $rule = Koha::IssuingRules->get_effective_issuing_rule(
        {
            categorycode => $checkout->patron->categorycode,
            itemtype     => $checkout->item->effective_itemtype,
            branchcode   => $checkout->branchcode,
        }
    );
    return $c->render(
        status => 200,
        openapi => {
            allows_renewal => $renewable,
            max_renewals => $rule->renewalsallowed,
            current_renewals => $checkout->renewals,
            unseen_renewals => $checkout->unseen_renewals,
            error => $error
        }
    );
}

=head3 _to_api

Helper function that maps a hashref of Koha::Checkout attributes into REST api
attribute names.

=cut

sub _to_api {
    my $checkout = shift;

    foreach my $column ( keys %{ $Koha::REST::V1::Checkouts::to_api_mapping } ) {
        my $mapped_column = $Koha::REST::V1::Checkouts::to_api_mapping->{$column};
        if ( exists $checkout->{ $column } && defined $mapped_column )
        {
            $checkout->{ $mapped_column } = delete $checkout->{ $column };
        }
        elsif ( exists $checkout->{ $column } && !defined $mapped_column ) {
            delete $checkout->{ $column };
        }
    }
    return $checkout;
}

=head3 _to_model

Helper function that maps REST api objects into Koha::Checkouts
attribute names.

=cut

sub _to_model {
    my $checkout = shift;

    foreach my $attribute ( keys %{ $Koha::REST::V1::Checkouts::to_model_mapping } ) {
        my $mapped_attribute = $Koha::REST::V1::Checkouts::to_model_mapping->{$attribute};
        if ( exists $checkout->{ $attribute } && defined $mapped_attribute )
        {
            $checkout->{ $mapped_attribute } = delete $checkout->{ $attribute };
        }
        elsif ( exists $checkout->{ $attribute } && !defined $mapped_attribute )
        {
            delete $checkout->{ $attribute };
        }
    }
    return $checkout;
}

=head2 Global variables

=head3 $to_api_mapping

=cut

our $to_api_mapping = {
    issue_id        => 'checkout_id',
    borrowernumber  => 'patron_id',
    itemnumber      => 'item_id',
    date_due        => 'due_date',
    branchcode      => 'library_id',
    returndate      => 'checkin_date',
    lastreneweddate => 'last_renewed_date',
    issuedate       => 'checkout_date',
    notedate        => 'note_date',
};

=head3 $to_model_mapping

=cut

our $to_model_mapping = {
    checkout_id       => 'issue_id',
    patron_id         => 'borrowernumber',
    item_id           => 'itemnumber',
    due_date          => 'date_due',
    library_id        => 'branchcode',
    checkin_date      => 'returndate',
    last_renewed_date => 'lastreneweddate',
    checkout_date     => 'issuedate',
    note_date         => 'notedate',
    checked_in        => undef,
};

1;
