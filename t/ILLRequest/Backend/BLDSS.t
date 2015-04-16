#!/usr/bin/perl

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

use Test::Exception;
use Test::More;
use Test::MockObject;
use Test::Warn;

# Preparation.
sub populate {
    my ( $obj, $methods ) = @_;
    while ( my ( $method, $value ) = each $methods ) {
        $obj->set_always($method, $value);
    }
}

my $brw = Test::MockObject->new;
my $brw_methods = {
    email => 'test@test.com',
};
populate($brw, $brw_methods);

my $brn = {
    branchaddress1 => "line1",
    branchaddress2 => "line2",
    branchcity     => "city",
    branchzip      => "zip",
    branchaddress3 => "line3",
    branchstate    => "state",
    branchcountry  => "United Kingdom",
};

my ( @result, @expected, $name );
my $class_obj = Koha::ILLRequest::Backend::BLDSS->new;

# Begin Tests

BEGIN {
        use_ok('Koha::ILLRequest::Backend::BLDSS');
}

## validate_delivery_input
### digital valid
@result = $class_obj->validate_delivery_input( {
    service  => { format => 1 },
    borrower => $brw,
    branch   => $brn,
} );
@expected = ( 0, { email => $brw_methods->{email} } );
$name = "validate_delivery_input, digital, valid";
is_deeply( \@result, \@expected, $name );

### digital invalid email
$brw->set_always('email', "");
$name = "validate_delivery_input, digital, invalid email";
dies_ok { $class_obj->validate_delivery_input( {
    service  => { format => 1 },
    borrower => $brw,
    branch   => $brn,
} ) }
    $name;

### physical valid
@result = $class_obj->validate_delivery_input( {
    service  => { format => 4 },
    borrower => $brw,
    branch   => $brn,
} );
@expected = ( 0, {
    Address => {
        AddressLine1     => $brn->{branchaddress1},
        AddressLine2     => $brn->{branchaddress2},
        TownOrCity       => $brn->{branchcity},
        PostOrZipCode    => $brn->{branchzip},
        AddressLine3     => $brn->{branchaddress3},
        CountyOrState    => $brn->{branchstate},
        ProvinceOrRegion => "",
        Country          => "gbr",
    }
} );
$name = "validate_delivery_input, physical, valid";
is_deeply( \@result, \@expected, $name );

### physical invalid Mandatory fields
foreach ( qw/ branchaddress1 branchaddress2 branchcity branchzip / ) {
    my $tmp = $brn->{$_};
    $brn->{$_} = "";
    $name = "validate_delivery_input, physical, invalid mandatories";
    dies_ok { $class_obj->validate_delivery_input( {
        service  => { format => 4 },
        borrower => $brw,
        branch   => $brn,
    } ) }
        $name;
    $brn->{$_} = $tmp;
}

### physical invalid country
my $tmp = $brn->{branchcountry};
$brn->{branchcountry} = "blah";
$name = "validate_delivery_input, physical, invalid country";
dies_ok { $class_obj->validate_delivery_input( {
    service  => { format => 4 },
    borrower => $brw,
    branch   => $brn,
} ) }
    $name;
$brn->{branchcountry} = $tmp;

done_testing;
