package Koha::Objects::Mixin::ExtendedAttributes;

# Copyright 2024 PTFS Europe Ltd
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

=head1 NAME

Koha::Objects::Mixin::ExtendedAttributes

=head2 Class methods

=head3 _build_extended_attributes_relations

Method to dynamically add has_many relations for Koha classes that support extended_attributes.

Used in the API to allow for advanced joins.

Returns a list of relation accessor names.

=cut

sub _build_extended_attributes_relations {
    my ( $self, $types ) = @_;

    my $ea_config = $self->extended_attributes_config;

    my $result_source = $self->_resultset->result_source;
    for my $type ( @{$types} ) {
        $result_source->add_relationship(
            "extended_attributes_$type",
            "$ea_config->{schema_class}",
            sub {
                my $args = shift;

                return {
                    "$args->{foreign_alias}.$ea_config->{id_field}" =>
                        { -ident => "$args->{self_alias}.$ea_config->{id_field}" },
                    "$args->{foreign_alias}.$ea_config->{key_field}" => { '=', $type },
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

1;