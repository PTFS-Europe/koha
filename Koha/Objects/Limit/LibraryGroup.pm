package Koha::Objects::Limit::LibraryGroup;

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

use C4::Context;
use Koha::Database;

=head1 NAME

Koha::Objects::Limit::LibraryGroup - Generic library group limit handling class

=head1 SYNOPSIS

    use base qw(Koha::Objects Koha::Objects::Limit::LibraryGroup);
    my $objects = Koha::Objects->search_with_library_grouplimits( $params, $attributes, $library_group_id );

=head1 DESCRIPTION

This class is provided as a generic way of handling library group limits for Koha::Objects-based classes
in Koha.

This class must always be subclassed.

=head1 API

=head2 Class methods

=cut

=head3 define_library_group_limits

my $results = $objects->define_library_group_limits( $params, $attributes, $library_group_id );

Wrapper method for searching objects with library limits, respecting those limits

=cut

sub define_library_group_limits {
    my ( $self, $params, $attributes ) = @_;

    my $logged_in_branch = C4::Context->userenv()->{'branch'} || undef;
    return ( $params, $attributes ) unless $logged_in_branch;

    my $lib_group_visibility_parameters = $self->object_class()->_library_group_visibility_parameters;

    my $library = Koha::Libraries->find($logged_in_branch);
    return ( $params, $attributes ) unless $library;

    my $visibility_column = $lib_group_visibility_parameters->{visibility_column};
    my $library_group_limits_table =
        Koha::Database->new->schema->resultset( $lib_group_visibility_parameters->{class} )->result_source->name;

    my $where = {
        '-or' => [
            { "$visibility_column" => undef },
        ]
    };

    my @library_groups = $library->library_groups->as_list;
    my @parent_ids;

    return ( $params, $attributes ) if scalar(@library_groups) == 0;

    foreach my $library_group (@library_groups) {
        my $group_id = $library_group->id;
        my $query    = {};
        $query->{"$visibility_column"} = { "-like" => "%|$group_id|%" };
        push( @{ $where->{'-or'} }, $query );

        _handle_parent_groups(
            {
                library_group     => $library_group, where => $where, parent_ids => \@parent_ids,
                visibility_column => $visibility_column
            }
        );
    }

    $params     //= {};
    $attributes //= {};

    if ( ref($params) eq 'ARRAY' ) {
        foreach my $query (@$params) {
            $query = { %$query, %$where };
        }
    } else {
        $params = { %$params, %$where };
    }

    return ( $params, $attributes );
}

=head3 _handle_parent_groups

_handle_parent_groups(
    {
        library_group     => $library_group, where => $where, parent_ids => \@parent_ids,
        visibility_column => $visibility_column
    }
);

Recursively handles parent library groups to account for multiple sub groups

=cut

sub _handle_parent_groups {
    my ($args) = @_;

    my $library_group     = $args->{library_group};
    my $where             = $args->{where};
    my $parent_ids        = $args->{parent_ids};
    my $visibility_column = $args->{visibility_column};

    my $parent = $library_group->parent;
    if ( $parent && !grep( $_ eq $parent->id, @$parent_ids ) ) {
        my $parent_query = {};
        my $parent_id    = $parent->id;
        push( @$parent_ids, $parent_id );
        $parent_query->{"$visibility_column"} = { "-like" => "%|$parent_id|%" };
        push( @{ $where->{'-or'} }, $parent_query );
        _handle_parent_groups(
            {
                library_group     => $parent, where => $where, parent_ids => $parent_ids,
                visibility_column => $visibility_column
            }
        );
    }
}

1;
