package Koha::Object::Mixin::ExtendedAttributes;

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

Koha::Object::Mixin::ExtendedAttributes

=head2 Class methods


=head3 AUTOLOAD

=cut

our $AUTOLOAD;

# This class is not yet utilized, but we'll need it if we ever want to support this sort of syntax:
# ill_request->extended_attributes_author; and get the 'author' extended_attributes from the ill_request
# TODO: This needs to be abstracted in the future, currently only considering ILL

sub AUTOLOAD {
    my ($self) = @_;

    my $name = $AUTOLOAD;
    $name =~ s/.*:://;    # Remove package name

    if ( $name =~ /^extended_attributes_(\w+)$/ ) {
        my $type = $1;

        # Define the method dynamically
        no strict 'refs';
        *{$AUTOLOAD} = sub {
            my ($self)   = @_;
            my $relation = 'extended_attributes_' . $type;
            my $rs       = $self->_result->$relation;
            return Koha::ILL::Request::Attributes->_new_from_dbic($rs)->search;
        };

        # Call the newly defined method
        return $self->$name();
    }
    my $wt = 'SUPER::' . $name;
    return $self->$wt;
}

1;