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

use Test::More tests => 3;
use Test::Exception;
use Test::Warn;

use Koha::SFTP::Servers;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $sftp_server = $builder->build_object({ class => 'Koha::SFTP::Servers', });

    ## create a password
    $sftp_server->set({ password => 'test123' })->store;

    ok( $sftp_server->password ne 'test123', 'Password should not be in plain text' );
    is( length($sftp_server->password), 64, 'Password has should be 64 characters long' );

    $schema->storage->txn_rollback;
};

subtest 'to_api() tests' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $sftp_server = $builder->build_object({ class => 'Koha::SFTP::Servers' });
    ok( !exists $sftp_server->to_api->{password}, 'Password is not part of the API representation' );

    $schema->storage->txn_rollback;
};

subtest 'plain_text_password() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $sftp_server = $builder->build_object({ class => 'Koha::SFTP::Servers', });

    ## create a password
    $sftp_server->set({ password => 'test123' })->store;

    ## retrieve it back out
    my $sftp_server_plain_text_password = $sftp_server->plain_text_password;

    isnt( $sftp_server_plain_text_password, $sftp_server->password, 'Password and password hash shouldn\'t match' );
    is  ( $sftp_server_plain_text_password, 'test123', 'Password should be in plain text' );

    $schema->storage->txn_rollback;
};
