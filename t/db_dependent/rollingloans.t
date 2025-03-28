#!/usr/bin/perl

use Modern::Perl;
use C4::Context;
use C4::Circulation qw( CanBookBeIssued AddIssue AddReturn );
use C4::Members;
use C4::Items;
use Koha::DateUtils qw( dt_from_string );
use Koha::Libraries;
use Koha::Patrons;
use t::lib::TestBuilder;
use t::lib::Mocks qw(mock_preference);

use Test::NoWarnings;
use Test::More tests => 9;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
$builder->build( { source => 'Branch', value => { branchcode => 'CPL' } } )
    unless Koha::Libraries->find('CPL');

t::lib::Mocks::mock_userenv( { branchcode => 'CPL' } );

t::lib::Mocks::mock_preference( 'BlockReturnOfWithdrawnItems', 0 );
my $test_patron   = '23529001223651';
my $test_item_fic = '502326000402';
my $test_item_24  = '502326000404';
my $test_item_48  = '502326000403';

my $borrower1 = $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => $test_patron } } );
my $item1     = $builder->build_sample_item(
    {
        barcode => $test_item_fic,
    }
);
my $item2 = $builder->build_sample_item(
    {
        barcode => $test_item_24,
    }
);
my $item3 = $builder->build_sample_item(
    {
        barcode => $test_item_48,
    }
);

SKIP: {
    skip 'Missing test borrower or item, skipping tests', 8
        unless ( defined $borrower1 && defined $item1 );

    for my $item_barcode ( $test_item_fic, $test_item_24, $test_item_48 ) {
        my $duedate = try_issue( $test_patron, $item_barcode );
        isa_ok( $duedate, 'DateTime' );
        if ( $item_barcode eq $test_item_fic ) {
            is( $duedate->hour(),   23, "daily loan hours = 23" );
            is( $duedate->minute(), 59, "daily loan mins = 59" );
        }
        my $ret_ok = try_return($item_barcode);
        is( $ret_ok, 1, 'Return succeeded' );
    }
}

sub try_issue {
    my ( $cardnumber, $item_barcode ) = @_;
    my $issuedate = '2011-05-16';
    my $patron    = Koha::Patrons->find( { cardnumber => $cardnumber } );
    my ( $issuingimpossible, $needsconfirmation ) = CanBookBeIssued( $patron, $item_barcode );
    my $issue = AddIssue( $patron, $item_barcode, undef, 0, $issuedate );
    return dt_from_string( $issue->date_due );
}

sub try_return {
    my $item_barcode = shift;
    my ( $ret, $messages, $iteminformation, $borrower ) = AddReturn($item_barcode);
    return $ret;
}
