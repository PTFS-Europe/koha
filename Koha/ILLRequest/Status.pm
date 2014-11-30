package Koha::ILLRequest::Status;

# Copyright PTFS Europe 2014
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
use Carp;

=head1 NAME

Koha::ILLRequest::Status - Koha ILL Status Object class

=head1 SYNOPSIS

=head1 DESCRIPTION

Currently this is hardcoded to database column names and there is no
configuration to map the fields to relevant fields in the API.  So for now it
is hard-coded to use BLDSS API.

=head1 API

=head2 Class Methods

=cut

=head3 new

=cut

sub new {
    my ( $class, $borrowernumber ) = @_;
    my $self = {
                borrowernumber  => $borrowernumber,
                biblionumber    => '',
                status          => 'new',
                placement_date  => 'today',
                reply_date      => '',
                ts              => '',
                completion_date => '',
                reqtype         => 'book',
                branch          => 'default',
               };

    bless $self, $class;

    return $self;
}

sub getFullStatus {
    my ( $self ) = @_;

    my $return = {
                  borrowernumber  => ${$self}{borrowernumber},
                  biblionumber    => ${$self}{biblionumber},
                  status          => ${$self}{status},
                  placement_date  => ${$self}{placement_date},
                  reply_date      => ${$self}{reply_date},
                  ts              => ${$self}{ts},
                  completion_date => ${$self}{completion_date},
                  reqtype         => ${$self}{reqtype},
                  branch          => ${$self}{branch},
                 };

    return $return;
}

sub getSummary {
    my ( $self ) = @_;
    my $summary = {
                   borrowernumber => [ "Borrower Number",
                                       ${$self}{borrowernumber} ],
                   biblionumber   => [ "Item Number",
                                       ${$self}{biblionumber} ],
                   status         => [ "Status", ${$self}{status} ],
                   reqtype        => [ "Request Type", ${$self}{reqtype} ],
                  };
    return $summary;
}

=head3 create_from_store


=cut

sub create_from_store {
    my ( $self, $attributes ) = @_;

    foreach my $field ( keys %{$self} ) {
        ${$self}{$field} = ${$attributes}{$field};
    }

    return $self;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
