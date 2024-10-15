package Koha::REST::V1::ERM::EHoldings::Titles;

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

use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );

use Koha::REST::V1::ERM::EHoldings::Titles::Local;
use Koha::REST::V1::ERM::EHoldings::Titles::EBSCO;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $provider = $c->param('provider');
    if ( $provider eq 'ebsco' ) {
        return Koha::REST::V1::ERM::EHoldings::Titles::EBSCO::list($c);
    } else {
        return Koha::REST::V1::ERM::EHoldings::Titles::Local::list($c);
    }
}

=head3 get

Controller function that handles retrieving a single Koha::ERM::EHoldings::Package object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $provider = $c->param('provider');
    if ( $provider eq 'ebsco' ) {
        return Koha::REST::V1::ERM::EHoldings::Titles::EBSCO::get($c);
    } else {
        return Koha::REST::V1::ERM::EHoldings::Titles::Local::get($c);
    }
}

=head3 add

Controller function that handles adding a new Koha::ERM::EHoldings::Title object

=cut

sub add{
    my $c = shift->openapi->valid_input or return;

    my $provider = $c->param('provider');
    if ( $provider && $provider eq 'ebsco' ) {
        die "invalid action";
    } else {
        return Koha::REST::V1::ERM::EHoldings::Titles::Local::add($c);
    }
}


=head3 update

Controller function that handles updating a Koha::ERM::EHoldings::Title object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $provider = $c->param('provider');
    if ( $provider && $provider eq 'ebsco' ) {
        die "invalid action";
    } else {
        return Koha::REST::V1::ERM::EHoldings::Titles::Local::update($c);
    }
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $provider = $c->param('provider');
    if ( $provider && $provider eq 'ebsco' ) {
        die "invalid action";
    } else {
        return Koha::REST::V1::ERM::EHoldings::Titles::Local::delete($c);
    }
}

=head3 import_from_list

Controller function that handles importing bibliographic record as local eholdings

=cut

sub import_from_list {
    my $c = shift->openapi->valid_input or return;

    return Koha::REST::V1::ERM::EHoldings::Titles::Local::import_from_list($c);
}

=head3 import_from_kbart_file

Controller function that handles importing a kbart file

=cut

sub import_from_kbart_file {
    my $c = shift->openapi->valid_input or return;

    return Koha::REST::V1::ERM::EHoldings::Titles::Local::import_from_kbart_file($c);
}

1;
