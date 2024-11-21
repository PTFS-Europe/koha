package Koha::Acquisition::FundManagement::Utils;

# Copyright 2024 PTFS Europe

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
use base qw(Koha::Object);

use Scalar::Util qw( looks_like_number );

=head3 cascade_lib_group_visibility

This method will update the visibility if the parent visibility has changed.
This only works if library groups have been removed i.e. new groups are not automatically cascaded
to prevent data being made visible where it shouldn't be.

=cut

sub cascade_lib_group_visibility {
    my ( $self, $args ) = @_;

    my $parent_visibility = $args->{parent_visibility};
    my $child             = $args->{child};
    my $change_detected;

    if ( $child->visible_to ne $parent_visibility ) {
        my @child_groups     = split( /\|/, $child->visible_to );
        my @parent_groups    = split( /\|/, $parent_visibility );
        my @groups_to_keep   = ();
        my @groups_to_delete = ();

        foreach my $group (@child_groups) {
            push( @groups_to_keep,   $group ) if grep( /^$group$/,  @parent_groups );
            push( @groups_to_delete, $group ) if !grep( /^$group$/, @parent_groups );
        }

        if ( scalar(@groups_to_delete) == 0 ) {
            $change_detected = 0;
        } else {
            my $new_visibility = scalar(@groups_to_keep) > 0 ? join( "|", @groups_to_keep ) : "";
            $change_detected = 1;
            $child->visible_to($new_visibility);
        }
    }
    return $change_detected;
}

=head3 cascade_status

This method will update the status if the parent status has changed
This only applies to a parent being set to "inactive". Activating a parent object again will not change the status of the child

=cut

sub cascade_status {
    my ( $self, $args ) = @_;

    my $parent_status = $args->{parent_status};
    my $child         = $args->{child};
    my $change_detected = 0;

    if ( $child->status != $parent_status && $parent_status == 0 ) {
        $child->status($parent_status);
        $change_detected = 1;
    }
    return $change_detected;
}


=head3 cascade_data

=cut

sub cascade_data {
    my ( $self, $args ) = @_;

    my $properties      = $args->{properties};
    my $parent          = $args->{parent};
    my $child           = $args->{child};
    my $change_detected = 0;

    foreach my $property (@$properties) {
        if( looks_like_number($property) ) {
            if ( $child->$property != $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        } else {
            if ( $child->$property ne $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        }
    }

    return $change_detected;
}

1;
