package Koha::Object::Limit::LibraryGroup;

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
use Koha::Exceptions;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::Object::Limit::LibraryGroup - Generic library group limit handling class

=head1 SYNOPSIS

    use base qw(Koha::Object Koha::Object::Limit::LibraryGroup);
    my $object = Koha::Object->new({ property1 => $property1, property2 => $property2, etc... } );

=head1 DESCRIPTION

This class is provided as a generic way of handling library group limits for Koha::Object-based classes
in Koha.

This class must always be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 lib_group_limits

A method that can be used to embed or simply retrieve the library group limits for an object

=cut

sub lib_group_limits {
    my ($self) = @_;

    my $lib_group_visibility_parameters = $self->object_class()->_library_group_visibility_parameters;
    my $visibility_column               = $lib_group_visibility_parameters->{visibility_column};

    my $lib_group_visibility = $self->$visibility_column;
    return [] if !$lib_group_visibility;

    my @ids = grep( /[0-9]/, split( /\|/, $lib_group_visibility ) );

    my @lib_groups = map { Koha::Library::Groups->find($_) } @ids;

    return \@lib_groups;
}

=head3 set_lib_group_visibility

A method that can be used to set the library group visibility for an object
If passed an array, it will format it into a string of "|" separated ids
If passed a string it will check it is formatted correctly and adjust it if needed

=cut

sub set_lib_group_visibility {
    my ( $self, $args ) = @_;

    my $new_visibility                  = $args->{new_visibility} || $self->lib_group_visibility;
    my $lib_group_visibility_parameters = $self->object_class()->_library_group_visibility_parameters;
    my $visibility_column               = $lib_group_visibility_parameters->{visibility_column};

    if ( ref $new_visibility eq 'ARRAY' ) {
        if ( scalar( @{$new_visibility} ) == 0 ) {
            $self->$visibility_column(undef);
            return $self;
        }
        $self->$visibility_column( join( "|", grep( /[0-9]/, @{$new_visibility} ) ) );
    }
    if ( $new_visibility && $new_visibility !~ /^\|.*\|$/ ) {
        $self->$visibility_column( "|" . $self->$visibility_column . "|" );
    }

    return $self;
}

1;
