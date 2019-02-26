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

use t::lib::Mocks;
use C4::Context;
use C4::Biblio qw( AddBiblio );
use Koha::Database;
use Koha::Libraries;
use C4::Calendar;
use Koha::Patrons;
use Koha::Holds;
use Koha::Item;
use Koha::DateUtils;
use t::lib::TestBuilder;

use Test::More tests => 29;
use Test::Exception;
use Test::Warn;

use_ok('Koha::Hold');

my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin();

# add two branches and a borrower
my $builder = t::lib::TestBuilder->new;
my @branches;
foreach( 1..2 ) {
    push @branches, $builder->build({ source => 'Branch' });
}
my $borrower = $builder->build({ source => 'Borrower' });

my $biblio = MARC::Record->new();
my $title  = 'Silence in the library';
$biblio->append_fields(
    MARC::Field->new( '100', ' ', ' ', a => 'Moffat, Steven' ),
    MARC::Field->new( '245', ' ', ' ', a => $title ),
);
my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $biblio, '' );

my $item = Koha::Item->new(
    {
        biblionumber     => $biblionumber,
        biblioitemnumber => $biblioitemnumber,
        holdingbranch    => $branches[0]->{branchcode},
        homebranch       => $branches[0]->{branchcode},
    }
);
$item->store();

my $hold = Koha::Hold->new(
    {
        biblionumber   => $biblionumber,
        itemnumber     => $item->id(),
        reservedate    => '2017-01-01',
        waitingdate    => '2000-01-01',
        borrowernumber => $borrower->{borrowernumber},
        branchcode     => $branches[1]->{branchcode},
        suspend        => 0,
    }
);
$hold->store();

my $b1_cal = C4::Calendar->new( branchcode => $branches[1]->{branchcode} );
$b1_cal->insert_single_holiday( day => 02, month => 01, year => 2017, title => "Morty Day", description => "Rick" ); #Add a holiday
my $today = dt_from_string;
is( $hold->age(), $today->delta_days( dt_from_string( '2017-01-01' ) )->in_units( 'days')  , "Age of hold is days from reservedate to now if calendar ignored");
is( $hold->age(1), $today->delta_days( dt_from_string( '2017-01-01' ) )->in_units( 'days' ) - 1 , "Age of hold is days from reservedate to now minus 1 if calendar used");

is( $hold->suspend, 0, "Hold is not suspended" );
$hold->suspend_hold();
is( $hold->suspend, 1, "Hold is suspended" );
$hold->resume();
is( $hold->suspend, 0, "Hold is not suspended" );
my $dt = dt_from_string();
$hold->suspend_hold( $dt );
$dt->truncate( to => 'day' );
is( $hold->suspend, 1, "Hold is suspended" );
is( $hold->suspend_until, "$dt", "Hold is suspended with a date, truncation takes place automatically" );
$hold->suspend_hold;
is( $hold->suspend, 1, "Hold is suspended" );
is( $hold->suspend_until, undef, "Hold is suspended without a date" );
$hold->resume();
is( $hold->suspend, 0, "Hold is not suspended" );
is( $hold->suspend_until, undef, "Hold no longer has suspend_until date" );

$item = $hold->item();

my $hold_borrower = $hold->borrower();
ok( $hold_borrower, 'Got hold borrower' );
is( $hold_borrower->borrowernumber(), $borrower->{borrowernumber}, 'Hold borrower matches correct borrower' );

t::lib::Mocks::mock_preference( 'ReservesMaxPickUpDelay', '5' );
$hold->found('T');
isnt( $hold->is_waiting, 1, 'The hold is not waiting (T)' );
is( $hold->is_found, 1, 'The hold is found');
is( $hold->is_in_transit, 1, 'The hold is in transit' );

$hold->found(q{});
isnt( $hold->is_waiting, 1, 'The hold is not waiting (W)' );
is( $hold->is_found, 0, 'The hold is not found' );
ok( !$hold->is_in_transit, 'The hold is not in transit' );

# Test method is_cancelable_from_opac
$hold->found(undef);
is( $hold->is_cancelable_from_opac, 1, "Unfound hold is cancelable" );
$hold->found('W');
is( $hold->is_cancelable_from_opac, 0, "Waiting hold is not cancelable" );
$hold->found('T');
is( $hold->is_cancelable_from_opac, 0, "In transit hold is not cancelable" );

# Test method is_at_destination
$hold->found(undef);
ok( !$hold->is_at_destination(), "Unfound hold cannot be at destination" );
$hold->found('T');
ok( !$hold->is_at_destination(), "In transit hold cannot be at destination" );
$hold->found('W');
ok( !$hold->is_at_destination(), "Waiting hold where hold branchcode is not the same as the item's holdingbranch is not at destination" );
$item->holdingbranch( $branches[1]->{branchcode} );
ok( $hold->is_at_destination(), "Waiting hold where hold branchcode is the same as the item's holdingbranch is at destination" );

$schema->storage->txn_rollback();

subtest "delete() tests" => sub {

    plan tests => 6;

    $schema->storage->txn_begin();

    # Disable logging
    t::lib::Mocks::mock_preference( 'HoldsLog', 0 );

    my $hold = $builder->build({ source => 'Reserve' });

    my $hold_object = Koha::Holds->find( $hold->{ reserve_id } );
    my $deleted = $hold_object->delete;
    is( $deleted, 1, 'Koha::Hold->delete should return 1 if the hold has been correctly deleted' );
    is( Koha::Holds->search({ reserve_id => $hold->{ reserve_id } })->count, 0,
        "Koha::Hold->delete should have deleted the hold" );

    my $number_of_logs = $schema->resultset('ActionLog')->search(
            { module => 'HOLDS', action => 'DELETE', object => $hold->{ reserve_id } } )->count;
    is( $number_of_logs, 0, 'With HoldsLogs, Koha::Hold->delete shouldn\'t have been logged' );

    # Enable logging
    t::lib::Mocks::mock_preference( 'HoldsLog', 1 );

    $hold = $builder->build({ source => 'Reserve' });

    $hold_object = Koha::Holds->find( $hold->{ reserve_id } );
    $deleted = $hold_object->delete;
    is( $deleted, 1, 'Koha::Hold->delete should return 1 if the hold has been correctly deleted' );
    is( Koha::Holds->search({ reserve_id => $hold->{ reserve_id } })->count, 0,
        "Koha::Hold->delete should have deleted the hold" );

    $number_of_logs = $schema->resultset('ActionLog')->search(
            { module => 'HOLDS', action => 'DELETE', object => $hold->{ reserve_id } } )->count;
    is( $number_of_logs, 1, 'With HoldsLogs, Koha::Hold->delete should have been logged' );

    $schema->storage->txn_rollback();
 };

subtest 'suspend() tests' => sub {

    plan tests => 16;

    $schema->storage->txn_begin;

    # Disable logging
    t::lib::Mocks::mock_preference( 'HoldsLog', 0 );

    my $hold = $builder->build_object(
        {   class => 'Koha::Holds',
            value => { found => undef, suspend => 0, suspend_until => undef, waitingdate => undef }
        }
    );

    ok( !$hold->is_suspended, 'Hold is not suspended' );
    my $suspended = $hold->suspend_hold;
    is( ref($suspended) , 'Koha::Hold', 'suspend returns the Koha::Hold object' );
    is( $suspended->id, $hold->id, 'suspend returns the same object' );
    ok( $suspended->is_suspended, 'The hold is suspended' );
    is( $suspended->suspend_until, undef, 'It is an indefinite suspension' );

    # resume the hold
    $suspended->resume;
    $hold->discard_changes;

    # create a DT
    my $date = dt_from_string()->add( days => 1 );
    $suspended = $hold->suspend_hold( $date );
    is( ref($suspended) , 'Koha::Hold', 'suspend returns the Koha::Hold object' );
    is( $suspended->id, $hold->id, 'suspend returns the same object' );
    ok( $suspended->is_suspended, 'The hold is suspended' );
    is( $suspended->suspend_until, $date->truncate( to => 'day' ), 'It is an indefinite suspension' );

    # resume the hold
    $suspended->resume;
    $hold->discard_changes;

    # set hold found=W
    $hold->set_waiting;
    throws_ok
        { $hold->suspend_hold; }
        'Koha::Exceptions::Hold::CannotSuspendFound',
        'Exception is thrown when a found hold is tried to suspend';

    is( $@->status, 'W', 'Exception gets the \'status\' parameter set correctly' );

    # set hold found=T
    $hold->set_waiting(1);
    throws_ok
        { $hold->suspend_hold; }
        'Koha::Exceptions::Hold::CannotSuspendFound',
        'Exception is thrown when a found hold is tried to suspend';

    is( $@->status, 'T', 'Exception gets the \'status\' parameter set correctly' );

    my $holds_module = Test::MockModule->new('Koha::Hold');
    $holds_module->mock( 'is_found', 1 );

    # bad data case
    $hold->found('X');
    throws_ok
        { $hold->suspend_hold }
        'Koha::Exceptions::Hold::CannotSuspendFound',
        'Exception is thrown when a found hold is tried to suspend';

    is( $@->error, 'Unhandled data exception on found hold (id='
                    . $hold->id
                    . ', found='
                    . $hold->found
                    . ')' , 'Exception gets the \'status\' parameter set correctly' );

    $holds_module->unmock( 'is_found' );

    # Enable logging
    t::lib::Mocks::mock_preference( 'HoldsLog', 1 );

    my $logs_count = $schema->resultset('ActionLog')->search(
            { module => 'HOLDS', action => 'SUSPEND', object => $hold->id } )->count;

    $hold = $builder->build_object(
        {   class => 'Koha::Holds',
            value => { suspend => 0, suspend_until => undef, waitingdate => undef, found => undef }
        }
    );

    $hold->suspend_hold;
    my $new_logs_count = $schema->resultset('ActionLog')->search(
            { module => 'HOLDS', action => 'SUSPEND', object => $hold->id } )->count;

    is( $new_logs_count, $logs_count + 1, 'If logging is enabled, suspending a hold gets logged' );

    $schema->storage->txn_rollback;
};
