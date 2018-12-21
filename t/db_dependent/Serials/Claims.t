use Modern::Perl;
use Test::More tests => 17;

use C4::Acquisition;
use C4::Budgets;
use Koha::Database;
use Koha::Acquisition::Booksellers;
use_ok('C4::Serials');

use Koha::DateUtils qw( dt_from_string output_pref );

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;
my $dbh = C4::Context->dbh;

$dbh->do(q|DELETE FROM issues|);
$dbh->do(q|DELETE FROM subscription|);

my $branchcode = 'CPL';
my $bpid = AddBudgetPeriod({
    budget_period_startdate   => '2015-01-01',
    budget_period_enddate     => '2015-12-31',
    budget_period_description => "budget desc"
});

my $budget_id = AddBudget({
    budget_code        => "ABCD",
    budget_amount      => "123.132",
    budget_name        => "Périodiques",
    budget_notes       => "This is a note",
    budget_period_id   => $bpid
});

my $record = MARC::Record->new();
my ( $biblionumber, $biblioitemnumber ) = C4::Biblio::AddBiblio($record, '');

my $sample_supplier1 = {
    name          => 'Name1',
    address1      => 'address1_1',
    address2      => 'address1-2',
    address3      => 'address1_2',
    address4      => 'address1_2',
    postal        => 'postal1',
    phone         => 'phone1',
    accountnumber => 'accountnumber1',
    fax           => 'fax1',
    url           => 'url1',
    active        => 1,
    gstreg        => 1,
    listincgst    => 1,
    invoiceincgst => 1,
    tax_rate       => '1.0000',
    discount      => '1.0000',
    notes         => 'notes1',
    deliverytime  => undef
};
my $sample_supplier2 = {
    name          => 'Name2',
    address1      => 'address1_2',
    address2      => 'address2-2',
    address3      => 'address3_2',
    address4      => 'address4_2',
    postal        => 'postal2',
    phone         => 'phone2',
    accountnumber => 'accountnumber2',
    fax           => 'fax2',
    url           => 'url2',
    active        => 1,
    gstreg        => 1,
    listincgst    => 1,
    invoiceincgst => 1,
    tax_rate       => '2.0000',
    discount      => '2.0000',
    notes         => 'notes2',
    deliverytime  => 2
};

my $supplier1 = Koha::Acquisition::Bookseller->new($sample_supplier1)->store;
my $supplier2 = Koha::Acquisition::Bookseller->new($sample_supplier2)->store;
my $supplier_id1 = $supplier1->id;
my $supplier_id2 = $supplier2->id;

my $supplierlist = eval { GetSuppliersWithLateIssues() };
is( length($@), 0, "No SQL problem in GetSuppliersWithLateIssues" );
is ( scalar(@$supplierlist), 0, 'There is no late issues yet');

my $subscriptionid_not_late = NewSubscription(
    undef,      $branchcode,     $supplier_id1, undef, $budget_id, $biblionumber,
    '2013-01-01', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '9999-01-01', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);
$supplierlist = GetSuppliersWithLateIssues();
is ( scalar(@$supplierlist), 0, 'There is still no late issues yet');

my $subscriptionid_inlate1 = NewSubscription(
    undef,      $branchcode,     $supplier_id1, undef, $budget_id, $biblionumber,
    '2013-01-01', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '2013-01-01', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);

my $subscriptionid_inlate2 = NewSubscription(
    undef,      $branchcode,     $supplier_id2, undef, $budget_id, $biblionumber,
    '2013-01-01', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '2013-01-01', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);

my $subscriptionid_inlate3 = NewSubscription(
    undef,      $branchcode,     $supplier_id2, undef, $budget_id, $biblionumber,
    '2013-01-02', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '2013-01-02', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);


$supplierlist = GetSuppliersWithLateIssues();
is ( scalar(@$supplierlist), 2, '2 suppliers should have issues in late');

is( GetLateOrMissingIssues(), undef, 'GetLateOrMissingIssues should return undef without parameter' );

my @late_or_missing_issues = GetLateOrMissingIssues( $supplier_id1 );
is( scalar(@late_or_missing_issues), 1, 'supplier 1 should have 1 issue in late' );

@late_or_missing_issues = GetLateOrMissingIssues( $supplier_id2);
is( scalar(@late_or_missing_issues), 2, 'supplier 2 should have 2 issues in late' );

is( exists $late_or_missing_issues[0]->{claimdate}, 1, 'GetLateOrMissingIssues returns claimdate' );
is( exists $late_or_missing_issues[0]->{claims_count}, 1, 'GetLateOrMissingIssues returns claims_count' );
is( $late_or_missing_issues[0]->{claims_count}, 0, 'The issues should not habe been claimed yet' );

is( updateClaim(), undef, 'updateClaim should return undef if not param passed' );
my $serialid_to_claim = $late_or_missing_issues[0]->{serialid};
updateClaim( $serialid_to_claim );

@late_or_missing_issues = GetLateOrMissingIssues( $supplier_id2);
is( scalar(@late_or_missing_issues), 2, 'supplier 2 should have 2 issues in late (already claimed issues are returns)' );

my ( $serial_claimed ) = grep { ($_->{serialid} == $serialid_to_claim) ? $_ : () } @late_or_missing_issues;
is( $serial_claimed->{claims_count}, 1, 'The serial should have been claimed' );

my @serials_to_claim = map { $_->{serialid} } @late_or_missing_issues;
updateClaim( \@serials_to_claim );
@late_or_missing_issues = GetLateOrMissingIssues( $supplier_id2);
is( scalar(@late_or_missing_issues), 2, 'supplier 2 should have 2 issues in late' );

( $serial_claimed ) = grep { ($_->{serialid} == $serials_to_claim[0]) ? $_ : () } @late_or_missing_issues;
is( $serial_claimed->{claims_count}, 2, 'The serial should have been claimed' );
( $serial_claimed ) = grep { ($_->{serialid} == $serials_to_claim[1]) ? $_ : () } @late_or_missing_issues;
is( $serial_claimed->{claims_count}, 1, 'The serial should have been claimed' );


my $today = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
# FIXME: This test should pass. The GetLateOrMissingIssues should not deal with date format!
#is( $serial_claimed->{claimdate}, $today, 'The serial should have been claimed today' );
