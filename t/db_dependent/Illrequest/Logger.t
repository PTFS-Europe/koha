
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

use Koha::Database;

use Test::More tests => 2;
use Test::MockModule;
use Test::MockObject;
use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Mock the modules we use
my $c4_log = Test::MockModule->new('C4::Log');
$c4_log->mock('logaction', sub { 1 });
my $c4_tpl = Test::MockModule->new('C4::Templates');
$c4_tpl->mock('_get_template_file',
    sub { return ('htdocs', 'theme', 'lang', 'base/'); });

use_ok('Koha::Illrequest::Logger');

subtest 'Basics' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $logger = Koha::Illrequest::Logger->new;

    # new()
    #
    ok( defined($logger), 'new() returned something' );
    ok( $logger->isa('Koha::Illrequest::Logger'),
        'new() returns the correct object' );

    # This is an incomplete data hashref, we use it to
    # test validation of the data before logging
    my $log_obj = {
        modulename   => 'modulename',
        actionname   => 'actionname',
        infos        => 'infos'
    };

    # log_something()
    #
    # Do we only log when the pref is set (currently unset)
    is($logger->log_something(), '',
        'logaction() not being called without pref being set');

    # Set the pref
    t::lib::Mocks::mock_preference( 'IllLog', 1 );
    # We should not log without all the required data, we are still
    # using the incomplete hashref
    is($logger->log_something(), '',
        'logaction() being called when data is incomplete');

    # Fix the data hashref, then test that logging occurs
    $log_obj->{objectnumber} = 'objectnumber';
    is($logger->log_something($log_obj), 1,
        'logaction() being called when pref is set and data is complete');

    # log_maybe()
    #
    is($logger->log_maybe({}, {}), '',
        'log_maybe() does not log with incomplete data');

    # get_log_template()
    #
    is(
        $logger->get_log_template({
            request => {},
            origin => 'core',
            action => 'STATUS_CHANGE'
        }),
        'base/status_change.tt',
        'get_log_template() fetches correct core template'
    );

    # logged_requested_partners
    my $categorycode = $builder->build({ source => 'Category' })->{categorycode};
    my $branchcode = $builder->build({ source => 'Branch' })->{branchcode};
    my $illrq = $builder->build_object({
        class => 'Koha::Illrequests',
        value => { borrowernumber => 123 }
    });
    my $config = Test::MockObject->new;
    $config->set_always('partner_code', $categorycode);
    $illrq->_config($config);
    Koha::Patron->new(
        {
            surname      => 'Test 1',
            email        => 'me@nowhere.com',
            categorycode => $categorycode,
            branchcode   => $branchcode
        }
    )->store();
    my $returned = Koha::Illrequest::Logger::_logged_requested_partners({
        request => $illrq,
        info => {
            log_origin => "core",
            status_before => "GENREQ",
            status_after => "GENREQ",
            additional => {
                partner_email_previous => 'me@nowhere.com',
                partner_email_now => 'you@nowhere.com'
            }
        }
    });
    isa_ok($returned, 'HASH',
        'logged_requested_partners returns a hasref'
    );
    is($returned->{'me@nowhere.com'}->{surname}, 'Test 1',
        'logged_requested_partners returns full patron objects');

    $schema->storage->txn_rollback;
};

1;
