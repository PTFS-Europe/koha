package C4::ILL::Config;
use strict;
use warnings;

# Copyright 2013,2014 PTFS Europe Ltd
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

use C4::Context;
our $VERSION = '1.00';

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;
    return $self;
}

sub new_request_status {
    my $self = shift;

    return 'NEW';
}

#sub auth_values {
#   my ($self, $category) = @_;
#   #    my $dbh          = C4::Context->dbh;
#    return $dbh->selectall_arrayref(
#'select authorised_value,lib,id from authorised_values where category=? order by lib asc',
#        { Slice => {} },
#        $category
#    );
#}


1;
