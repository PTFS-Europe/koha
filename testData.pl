use Modern::Perl;

use t::lib::TestBuilder;

use C4::Acquisition qw( NewBasket );
use C4::Biblio      qw( AddBiblio );
use C4::Budgets     qw( AddBudgetPeriod AddBudget );
use C4::Serials     qw( NewSubscription SearchSubscriptions );
use C4::Contract qw(
    AddContract
    DelContract
    GetContract
    GetContracts
    ModContract
);


use Koha::Acquisition::Booksellers;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );

my $schema  = Koha::Database->schema();
my $builder = t::lib::TestBuilder->new;


    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );

    # Add two baskets
    my $basket_1_id = C4::Acquisition::NewBasket( $vendor->id, $patron->borrowernumber, 'basketname1' );
    my $basket_2_id = C4::Acquisition::NewBasket( $vendor->id, $patron->borrowernumber, 'basketname2' );

    my $basket_1 = Koha::Acquisition::Baskets->find( $basket_1_id );
    my $basket_2 = Koha::Acquisition::Baskets->find( $basket_2_id );
    $basket_1->create_items('ordering')->store;
    $basket_2->create_items('ordering')->store;

    my $dt_today = dt_from_string;
    my $today    = output_pref( { dt => $dt_today, dateformat => 'iso', timeformat => '24hr', dateonly => 1 } );

    my $dt_today1 = dt_from_string;
    my $dur5      = DateTime::Duration->new( days => -5 );
    $dt_today1->add_duration($dur5);
    my $daysago5 = output_pref( { dt => $dt_today1, dateformat => 'iso', timeformat => '24hr', dateonly => 1 } );

    my $budgetperiod = C4::Budgets::AddBudgetPeriod(
        {
            budget_period_startdate   => $daysago5,
            budget_period_enddate     => $today,
            budget_period_description => "budget desc"
        }
    );
    my $id_budget = AddBudget(
        {
            budget_code      => "CODE",
            budget_amount    => "123.132",
            budget_name      => "Budgetname",
            budget_notes     => "This is a note",
            budget_period_id => $budgetperiod
        }
    );
    my $bib = MARC::Record->new();
    $bib->append_fields(
        MARC::Field->new( '245', ' ', ' ', a => 'Journal of ethnology', b => 'A subtitle' ),
        MARC::Field->new( '500', ' ', ' ', a => 'bib notes' ),
    );
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $bib, '' );

    # Add two subscriptions
    my $subscription_1_id = NewSubscription(
        undef,        'BRANCH2',     $vendor->id,          undef,
        $id_budget,   $biblionumber, '2013-01-01',         undef,
        undef,        undef,         undef,                undef,
        undef,        undef,         undef,                undef,
        undef,        1,             "subscription notes", undef,
        '2013-01-01', undef,         undef,                undef,
        'CALL ABC',   0,             "intnotes",           0,
        undef,        undef,         0,                    undef,
        '2013-11-30', 0
    );

    my $id_subscription2 = NewSubscription(
        undef,        'BRANCH2',     $vendor->id,          undef,
        $id_budget,   $biblionumber, '2013-01-01',         undef,
        undef,        undef,         undef,                undef,
        undef,        undef,         undef,                undef,
        undef,        1,             "subscription notes", undef,
        '2013-01-01', undef,         undef,                undef,
        'CALL DEF',   0,             "intnotes",           0,
        undef,        undef,         0,                    undef,
        '2013-07-31', 0
    );


    # Add two contacts
    my $contact_1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Bookseller::Contacts',
            value => { booksellerid => $vendor->id }
        }
    );
    my $contact_2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Bookseller::Contacts',
            value => { booksellerid => $vendor->id }
        }
    );

    $vendor->aliases( [ { alias => 'alias 1' }, { alias => 'alias 2' } ] );

    $vendor->interfaces( [ { name => 'first interface' }, { name => 'second interface', login => 'one_login' } ] );

    $vendor->interfaces( [ { name => 'first interface', login => 'one_login', password => 'oneP@sswOrd' } ] );

    Koha::Acquisition::Bookseller::Issue->new(
        {
            vendor_id => $vendor->id,
            type      => 'MAINTENANCE',
            notes     => 'a vendor issue'
        }
    )->store;

    my $my_contract1 = {
        contractstartdate   => '2014-06-01',
        contractenddate     => '2014-06-30',
        contractname        => 'My contract name',
        contractdescription => 'My contract description',
        booksellerid        => $vendor->id,
    };
    my $my_contract_id1 = AddContract($my_contract1);


# use Modern::Perl;

# use t::lib::TestBuilder;
# use t::lib::Mocks;

# use Koha::Database;

# my $schema  = Koha::Database->schema;
# my $builder = t::lib::TestBuilder->new;

# for ( 1 .. 1 ) {
#     my $vendor = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Booksellers',
#         }
#     );
#     my $basket = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Baskets',
#             value => {
#                 booksellerid => $vendor->id
#             }
#         }
#     );
#     my $basketgroup = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::BasketGroups',
#             value => {
#                 booksellerid => $vendor->id
#             }
#         }
#     );
#     my $contact = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Bookseller::Contacts',
#             value => {
#                 booksellerid => $vendor->id
#             }
#         }
#     );
#     my $issue = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Bookseller::Issues',
#             value => {
#                 vendor_id => $vendor->id
#             }
#         }
#     );
#     my $subscription = $builder->build_object(
#         {
#             class => 'Koha::Subscriptions',
#             value => {
#                 aqbooksellerid => $vendor->id
#             }
#         }
#     );
#     my $alias = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Bookseller::Aliases',
#             value => {
#                 vendor_id => $vendor->id
#             }
#         }        
#     );

#     my $interface = $builder->build_object(
#         {
#             class => 'Koha::Acquisition::Bookseller::Interfaces',
#             value => {
#                 vendor_id => $vendor->id
#             }
#         }        
#     );
# }
