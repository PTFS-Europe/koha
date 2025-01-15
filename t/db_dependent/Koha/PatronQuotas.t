use Modern::Perl;
use Test::More tests => 3;
use Test::Exception;
use Koha::Database;
use Koha::PatronQuota;
use Koha::PatronQuotas;
use Koha::Patrons;
use t::lib::TestBuilder;
use Koha::DateUtils qw( dt_from_string );

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Basic CRUD tests' => sub {
    plan tests => 7;
    
    $schema->storage->txn_begin;
    
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    
    my $quota = Koha::PatronQuota->new({
        patron_id => $patron->borrowernumber,
        quota_total => 100,
        quota_used => 0,
        period_start => '2024-01-01',
        period_end => '2024-12-31'
    })->store;
    
    ok($quota, 'Quota created successfully');
    is($quota->quota_total, 100, 'Quota total is correct');
    
    $quota->add_to_quota(25);
    is($quota->quota_used, 25, 'Used quota updated correctly');
    
    my $available = $quota->available_quota;
    is($available, 75, 'Available quota calculated correctly');
    ok($quota->has_available_quota, 'Has available quota when positive');
    
    # Test zero quota
    $quota->add_to_quota(50);  # Now at 75 used
    $quota->quota_used(100);   # Set to exactly match total
    ok($quota->has_available_quota, 'Has available quota when zero remaining');
    
    $quota->add_to_quota(1);
    ok(!$quota->has_available_quota, 'No available quota when negative');
    
    $schema->storage->txn_rollback;
};

subtest 'Search methods' => sub {
    plan tests => 3;
    
    $schema->storage->txn_begin;
    
    my $today = dt_from_string;
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    
    # Create test data directly instead of using TestBuilder
    my $quota = Koha::PatronQuota->new({
        patron_id => $patron->borrowernumber,
        quota_total => 100,
        quota_used => 0,
        period_start => $today->ymd,
        period_end => $today->clone->add(days => 30)->ymd
    })->store;
    
    # Test searching
    my $quotas = Koha::PatronQuotas->new;
    my $found = $quotas->get_patron_quota($patron->borrowernumber);
    ok($found, 'Found quota for patron') or diag("No quota found for patron " . $patron->borrowernumber);
    
    SKIP: {
        skip "No quota found", 1 unless $found;
        is($found->patron_id, $patron->borrowernumber, 'Correct patron quota found');
    }
    
    my $patron_quotas = $quotas->search_by_patron($patron->borrowernumber);
    ok($patron_quotas->count, 'Found quotas for patron');
    
    $schema->storage->txn_rollback;
};

subtest 'Active quotas tests' => sub {
    plan tests => 4;
    
    $schema->storage->txn_begin;
    
    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $today = dt_from_string;
    
    # Create expired quota
    my $expired = Koha::PatronQuota->new({
        patron_id => $patron->borrowernumber,
        quota_total => 100,
        quota_used => 0,
        period_start => $today->clone->subtract(days => 60)->ymd,
        period_end => $today->clone->subtract(days => 30)->ymd
    })->store;
    
    # Create active quota
    my $active = Koha::PatronQuota->new({
        patron_id => $patron->borrowernumber,
        quota_total => 100,
        quota_used => 0,
        period_start => $today->clone->subtract(days => 15)->ymd,
        period_end => $today->clone->add(days => 15)->ymd
    })->store;
    
    # Create future quota
    my $future = Koha::PatronQuota->new({
        patron_id => $patron->borrowernumber,
        quota_total => 100,
        quota_used => 0,
        period_start => $today->clone->add(days => 30)->ymd,
        period_end => $today->clone->add(days => 60)->ymd
    })->store;
    
    my $quotas = Koha::PatronQuotas->new;
    my $active_quotas = $quotas->get_active_quotas;
    
    is($active_quotas->count, 1, 'Found exactly one active quota');
    is($active_quotas->next->quota_id, $active->quota_id, 'Found correct active quota');
    
    ok(!$expired->is_active, 'Expired quota shows as inactive');
    ok(!$future->is_active, 'Future quota shows as inactive');
    
    $schema->storage->txn_rollback;
};

1;