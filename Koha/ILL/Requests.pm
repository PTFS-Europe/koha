package Koha::ILL::Requests;

# Copyright PTFS Europe 2016
#
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

use Koha::Database;
use Koha::ILL::Request;
use Koha::ILL::Request::Config;

use base qw(Koha::Objects);

=head1 NAME

Koha::ILL::Requests - Koha Illrequests Object class

=head1 API

=head2 Class methods

##### To be implemented Facade

=head3 new

    my $illRequests = Koha::ILL::Requests->new();

Create an ILLREQUESTS object, a singleton through which we can interact with
ILLREQUEST objects stored in the database or search for ILL candidates at API
backends.

=cut

sub new {
    my ( $class, $attributes ) = @_;

    my $self = $class->SUPER::new($class, $attributes);

    my $config = Koha::ILL::Request::Config->new; # <- Necessary
    $self->{_config} = $config;                 # <- Necessary

    return $self;
}

=head3 filter_by_visible

    my $visible_requests = $requests->filter_by_visible;

Returns a I<Koha::ILL::Requests> resultset, filtered by statuses that are not listed
as hidden in the I<ILLHiddenRequestStatuses> system preference.

=cut

sub filter_by_visible {
    my ($self) = @_;

    my $hidden_statuses_string = C4::Context->preference('ILLHiddenRequestStatuses') // q{};
    my $hidden_statuses = [ split '\|', $hidden_statuses_string ];

    if ( scalar @{$hidden_statuses} ) {
        return $self->search(
            {
                -and => {
                    status => { 'not in' => $hidden_statuses },
                    status_alias => [ -or =>
                        { 'not in' => $hidden_statuses },
                        { '=' => undef }
                    ]
                }
            }
        );
    }

    return $self;
}

=head3 search_incomplete

    my $requests = $illRequests->search_incomplete;

A specialised version of `search`, returning all requests currently
not considered completed.

=cut

sub search_incomplete {
    my ( $self ) = @_;
    $self->search( {
        status => [
            -and => { '!=', 'COMP' }, { '!=', 'GENCOMP' }
        ]
    } );
}

=head2 Internal methods


=head3 _build_extended_attributes_relations

Method to dynamically add has_many relations for each ILLRequestAttribute type stored in the ILLRequestAttributes table.

Used in the API to allow for advanced joins.

Returns a list of relation accessor names.

=cut

sub _build_extended_attributes_relations {
    my ( $self, $types ) = @_;

    my $result_source = $self->_resultset->result_source;
    for my $type ( @{$types} ) {
        $result_source->add_relationship(
            "extended_attributes_$type",
            "Koha::Schema::Result::Illrequestattribute",
            sub {
                my $args = shift;

                return {
                    "$args->{foreign_alias}.illrequest_id" => { -ident => "$args->{self_alias}.illrequest_id" },
                    "$args->{foreign_alias}.type"          => { '=', $type },
                };
            },
            {
                accessor       => 'multi',
                join_type      => 'LEFT',
                cascade_copy   => 0,
                cascade_delete => 0,
                is_depends_on  => 0
            },
        );

    }
    return map { 'extended_attributes_' . $_ } @{$types};
}

=head3 _type

=cut

sub _type {
    return 'Illrequest';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ILL::Request';
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
