#!/usr/bin/perl

# tests for Koha::Token

# Copyright 2016 Rijksmuseum
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
use Test::More tests => 11;
use Test::Exception;
use Time::HiRes qw|usleep|;
use C4::Context;
use Koha::Token;

C4::Context->_new_userenv('DUMMY SESSION');
C4::Context->set_userenv(0,42,0,'firstname','surname', 'CPL', 'Library 1', 0, ', ');

my $tokenizer = Koha::Token->new;
is( length( $tokenizer->generate ), 1, "Generate without parameters" );
my $token = $tokenizer->generate({ length => 20 });
is( length($token), 20, "Token $token has 20 chars" );

my $id = $tokenizer->generate({ length => 8 });
my $csrftoken = $tokenizer->generate_csrf({ session_id => $id });
isnt( length($csrftoken), 0, "Token $csrftoken should not be empty" );

is( $tokenizer->check, undef, "Check without any parameters" );
my $result = $tokenizer->check_csrf({
    session_id => $id, token => $csrftoken,
});
is( $result, 1, "CSRF token verified" );

$result = $tokenizer->check({
    type => 'CSRF', id => $id, token => $token,
});
isnt( $result, 1, "This token is no CSRF token" );

# Test MaxAge parameter
my $age = 1; # 1 second
$result = $tokenizer->check_csrf({
    session_id => $id, token => $csrftoken, MaxAge => $age,
});
is( $result, 1, "CSRF token still valid within one second" );
usleep $age * 1000000 * 2; # micro (millionth) seconds + 100%
$result = $tokenizer->check_csrf({
    session_id => $id, token => $csrftoken, MaxAge => $age,
});
isnt( $result, 1, "CSRF token expired after one second" );

subtest 'Same id (cookie CGISESSID) with an other logged in user' => sub {
    plan tests => 2;
    $csrftoken = $tokenizer->generate_csrf({ session_id => $id });
    $result = $tokenizer->check_csrf({
        session_id => $id, token => $csrftoken,
    });
    is( $result, 1, "CSRF token verified" );
    C4::Context->set_userenv(0,43,0,'firstname','surname', 'CPL', 'Library 1', 0, ', ');
    $result = $tokenizer->check_csrf({
        session_id => $id, token => $csrftoken,
    });
    is( $result, '', "CSRF token is not verified if another logged in user is using the same id" );
};

subtest 'Same logged in user with another session (cookie CGISESSID)' => sub {
    plan tests => 2;
    C4::Context->set_userenv(0,42,0,'firstname','surname', 'CPL', 'Library 1', 0, ', ');
    $csrftoken = $tokenizer->generate_csrf({ session_id => $id });
    $result = $tokenizer->check_csrf({
        session_id => $id, token => $csrftoken,
    });
    is( $result, 1, "CSRF token verified" );
    # Get another session id
    $id = $tokenizer->generate({ length => 8 });
    $result = $tokenizer->check_csrf({
        session_id => $id, token => $csrftoken,
    });
    is( $result, '', "CSRF token is not verified if another session is used" );
};

subtest 'Pattern parameter' => sub {
    plan tests => 5;
    my $id = $tokenizer->generate({ pattern => '\d\d', length => 8 });
    is( length($id), 2, 'Pattern overrides length' );
    ok( $id =~ /\d{2}/, 'Two digits found' );
    $id = $tokenizer->generate({ pattern => '[A-Z]{10}' });
    is( length($id), 10, 'Check length again' );
    ok( $id !~ /[^A-Z]/, 'Only uppercase letters' );
    throws_ok( sub { $tokenizer->generate({ pattern => 'abc{d,e}', }) }, 'Koha::Exceptions::Token::BadPattern', 'Exception should be thrown when wrong pattern is used');
};
