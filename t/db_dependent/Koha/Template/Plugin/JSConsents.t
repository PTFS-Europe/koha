#!/usr/bin/perl

use Modern::Perl;

use C4::Context;

use Test::MockModule;
use Test::More tests => 3;
use t::lib::Mocks;

BEGIN {
    use_ok('Koha::Template::Plugin::JSConsents', "Can use Koha::Template::Plugin::JSConsents");
}

ok( my $consents = Koha::Template::Plugin::JSConsents->new(), 'Able to instantiate template plugin' );

subtest "all" => sub {
    plan tests => 1;

    t::lib::Mocks::mock_preference( 'ConsentJS', 'eyAidGVzdCI6ICJvbmUiIH0=' );

    is_deeply( $consents->all(), { test => 'one' }, 'Returns a Base64 decoded JSON object converted into a data structure');
};

1;
