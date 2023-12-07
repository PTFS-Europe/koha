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

my $original_dateformat                = C4::Context->preference('dateformat');
my $original_DefaultPatronSearchFields = C4::Context->preference('DefaultPatronSearchFields');
my $original_DefaultPatronSearchMethod = C4::Context->preference('DefaultPatronSearchMethod');
my $original_PatronsPerPage            = C4::Context->preference('PatronsPerPage');
our @cleanup;
our $DT_delay = 1;

END {
    unless ( @cleanup ) { say "WARNING: Cleanup failed!" }
    C4::Context->set_preference( 'dateformat',                $original_dateformat );
    C4::Context->set_preference( 'DefaultPatronSearchFields', $original_DefaultPatronSearchFields );
    C4::Context->set_preference( 'DefaultPatronSearchMethod', $original_DefaultPatronSearchMethod );
    C4::Context->set_preference( 'PatronsPerPage',            $original_PatronsPerPage );
    $_->delete for @cleanup;
};

use C4::Context;

use utf8;
use Test::More;
use Test::MockModule;

use C4::Context;
use Koha::AuthUtils;
use Koha::Patrons;
use t::lib::Mocks;
use t::lib::Selenium;
use t::lib::TestBuilder;

eval { require Selenium::Remote::Driver; };
if ( $@ ) {
    plan skip_all => "Selenium::Remote::Driver is needed for selenium tests.";
} else {
    plan tests => 1;
}

my $s             = t::lib::Selenium->new;
my $driver        = $s->driver;
my $opac_base_url = $s->opac_base_url;
my $base_url      = $s->base_url;
my $builder       = t::lib::TestBuilder->new;
my $schema        = Koha::Database->schema;

subtest 'Search patrons' => sub {
    plan tests => 28;

    if ( Koha::Patrons->search({surname => {-like => "test_patron_%"}})->count ) {
        BAIL_OUT("Cannot run this test, data we need to create already exist in the DB");
    }
    my @patrons;
    my $borrowernotes           = q|<strong>just 'a" note</strong> \123 ❤|;
    my $borrowernotes_displayed = q|just 'a" note \123 ❤|;
    my $branchname = q|<strong>just 'another" library</strong> \123 ❤|;
    my $firstname  = q|<strong>fir's"tname</strong> \123 ❤|;
    my $address    = q|<strong>add'res"s</strong> \123 ❤|;
    my $email      = q|a<strong>bad_email</strong>@example\123 ❤.com|;
    my $patron_category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => { category_type => 'A' }
        }
    );
    push @cleanup, $patron_category;

    my $library = $builder->build_object(
        { class => 'Koha::Libraries', value => { branchname => $branchname } }
    );
    push @cleanup, $library;

    for my $i ( 1 .. 25 ) {
        push @patrons,
          $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => {
                    surname       => "test_patron_" . $i++,
                    firstname     => $firstname,
                    categorycode  => $patron_category->categorycode,
                    branchcode    => $library->branchcode,
                    borrowernotes => $borrowernotes,
                    address       => $address,
                    email         => $email,
                }
            }
          );
    }

    push @patrons, $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                surname       => "test",
                firstname     => "not_p_a_t_r_o_n",                # won't match 'patron'
                categorycode  => $patron_category->categorycode,
                branchcode    => $library->branchcode,
                borrowernotes => $borrowernotes,
                address       => $address,
                email         => $email,
            }
        }
    );

    unshift @cleanup, $_ for @patrons;

    my $library_2 = $builder->build_object(
        { class => 'Koha::Libraries', value => { branchname => 'X' . $branchname } }
    );
    push @cleanup, $library_2;

    my $patron_27 =
      $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                surname       => "test_patron_27",
                firstname     => $firstname,
                categorycode  => $patron_category->categorycode,
                branchcode    => $library_2->branchcode,
                borrowernotes => $borrowernotes,
                address       => $address,
                email         => $email,
                dateofbirth   => '1980-06-17',
            }
        }
      );
    unshift @cleanup, $patron_27;

    my $attribute_type = Koha::Patron::Attribute::Type->new(
        {
            code        => 'my code1',
            description => 'my description1',
            staff_searchable => 0,
            searched_by_default => 0
        }
    )->store;
    my $attribute_type_searchable_1 = Koha::Patron::Attribute::Type->new(
        {
            code             => 'my code2',
            description      => 'my description2',
            opac_display     => 1,
            staff_searchable => 1,
            searched_by_default => 1
        }
    )->store;
    my $attribute_type_searchable_2 = Koha::Patron::Attribute::Type->new(
        {
            code             => 'my code3',
            description      => 'my description3',
            opac_display     => 1,
            staff_searchable => 1,
            searched_by_default => 1
        }
    )->store;
    my $attribute_type_searchable_not_default = Koha::Patron::Attribute::Type->new(
        {
            code             => 'mycode4',
            description      => 'my description4',
            opac_display     => 1,
            staff_searchable => 1,
            searched_by_default => 0
        }
    )->store;
    push @cleanup, $attribute_type, $attribute_type_searchable_1, $attribute_type_searchable_2, $attribute_type_searchable_not_default;

    $patrons[0]->extended_attributes([
        { code => $attribute_type->code, attribute => 'test_attr_1' },
        { code => $attribute_type_searchable_1->code, attribute => 'test_attr_2'},
        { code => $attribute_type_searchable_2->code, attribute => 'test_attr_3'},
        { code => $attribute_type_searchable_not_default->code, attribute => 'test_attr_4'},
    ]);
    $patrons[1]->extended_attributes([
        { code => $attribute_type->code, attribute => 'test_attr_1' },
        { code => $attribute_type_searchable_1->code, attribute => 'test_attr_2'},
        { code => $attribute_type_searchable_2->code, attribute => 'test_attr_3'},
        { code => $attribute_type_searchable_not_default->code, attribute => 'test_attr_4'},
    ]);

    my $total_number_of_patrons = Koha::Patrons->search->count;
    my $table_id = "memberresultst";

    $s->auth;
    C4::Context->set_preference('DefaultPatronSearchFields',"");
    C4::Context->set_preference('DefaultPatronSearchMethod',"contains");
    my $searchable_attributes = Koha::Patron::Attribute::Types->search({ staff_searchable => 1 })->count();
    my $PatronsPerPage = 15;
    my $nb_standard_fields = 13 + $searchable_attributes; # Standard fields, plus one searchable attribute
    C4::Context->set_preference('PatronsPerPage', $PatronsPerPage);
    $driver->get( $base_url . "/members/members-home.pl" );
    my @adv_options = $driver->find_elements('//select[@id="searchfieldstype"]/option');
    is( scalar @adv_options, $nb_standard_fields + 1, 'All standard fields are searchable if DefaultPatronSearchFields not set. middle_name is there.');
    is( $adv_options[0]->get_value(), 'standard', 'Standard search uses value "standard"');
    my @filter_options = $driver->find_elements('//select[@id="searchfieldstype_filter"]/option');
    is( scalar @filter_options, $nb_standard_fields + 1, 'All standard fields + middle_name are searchable by filter if DefaultPatronSearchFields not set');
    is( $filter_options[0]->get_value(), 'standard', 'Standard filter uses hard coded value "standard" DefaultPatronSearchFields not set');
    C4::Context->set_preference('DefaultPatronSearchFields',"firstname|initials");
    $driver->get( $base_url . "/members/members-home.pl" );
    @adv_options = $driver->find_elements('//select[@id="searchfieldstype"]/option');
    is( scalar @adv_options, $nb_standard_fields, 'New option added when DefaultPatronSearchFields is populated with a field. Note that middle_name disappears, we do not want it if not part of DefaultPatronSearchFields');
    is( $adv_options[0]->get_value(), 'standard', 'Standard search uses value "standard"');
    @filter_options = $driver->find_elements('//select[@id="searchfieldstype_filter"]/option');
    is( scalar @filter_options, $nb_standard_fields, 'New filter option added when DefaultPatronSearchFields is populated with a field');
    is( $filter_options[0]->get_value(), 'standard', 'Standard filter uses value "standard"');
    $driver->get( $base_url . "/members/members-home.pl" );
    @adv_options = $driver->find_elements('//select[@id="searchfieldstype"]/option');
    @filter_options = $driver->find_elements('//select[@id="searchfieldstype_filter"]/option');
    is( scalar @adv_options, $nb_standard_fields, 'Invalid option not added when DefaultPatronSearchFields is populated with an invalid field');
    is( scalar @filter_options, $nb_standard_fields, 'Invalid filter option not added when DefaultPatronSearchFields is populated with an invalid field');

    # NOTE: We should probably ensure the bad field is removed from 'standard' search here, else searches are broken
    C4::Context->set_preference('DefaultPatronSearchFields',"");
    $driver->get( $base_url . "/members/members-home.pl" );
    $s->fill_form( { search_patron_filter => 'test_patron' } );
    $s->submit_form;
    my $first_patron = $patrons[0];

    sleep $DT_delay && $s->wait_for_ajax;
    my @td = $driver->find_elements('//table[@id="'.$table_id.'"]/tbody/tr/td');
    like ($td[2]->get_text, qr[\Q$firstname\E],
        'Column "Name" should be the 3rd and contain the firstname correctly filtered'
    );
    like ($td[2]->get_text, qr[\Q$address\E],
        'Column "Name" should be the 3rd and contain the address correctly filtered'
    );
    like ($td[2]->get_text, qr[\Q$email\E],
        'Column "Name" should be the 3rd and contain the email address correctly filtered'
    );
    is( $td[4]->get_text, $branchname,
        'Column "Library" should be the 6th and contain the html tags - they have been html filtered'
    );
    is( $td[9]->get_text, $borrowernotes_displayed,
        'Column "Circ note" should be the 10th and not contain the html tags - they have not been html filtered'
    );

    $driver->find_element(
            '//a[@href="/cgi-bin/koha/members/memberentry.pl?op=modify&destination=circ&borrowernumber='
          . $first_patron->borrowernumber
          . '"]' )->click;
    is(
        $driver->get_title,
        sprintf(
            "Modify patron %s %s %s (%s) %s (%s) (%s) › Patrons › Koha",
            $first_patron->title, $first_patron->firstname, $first_patron->middle_name, $first_patron->othernames, $first_patron->surname, $first_patron->cardnumber,
            $first_patron->category->description,
        ),
        'Page title is correct after following modification link'
    );

    $driver->get( $base_url . "/members/members-home.pl" );
    $s->fill_form( { search_patron_filter => 'test_patron' } );
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    $s->driver->find_element('//*[@id="'.$table_id.'_filter"]//input')->send_keys('test_patron');
    sleep $DT_delay && $s->wait_for_ajax;
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', $PatronsPerPage, 26, $total_number_of_patrons), 'Searching in standard brings back correct results' );

    $s->driver->find_element('//table[@id="'.$table_id.'"]//th[@data-filter="libraries"]/select/option[@value="'.$library->branchcode.'"]')->click;
    sleep $DT_delay && $s->wait_for_ajax;
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', $PatronsPerPage, 25, $total_number_of_patrons), 'Filtering on library works in combination with main search' );

    # Reset the filters
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="clear_search"]')->click();
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    # And make sure all the patrons are present
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries', $PatronsPerPage, $total_number_of_patrons), 'Resetting filters works as expected' );

    # Pattern terms must be split
    $s->fill_form( { search_patron_filter => 'test patron' } );
    $s->submit_form;

    sleep $DT_delay && $s->wait_for_ajax;
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', $PatronsPerPage, 26, $total_number_of_patrons) );
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="clear_search"]')->click();
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    # Search on non-searchable attribute, we expect no result!
    $s->fill_form( { search_patron_filter => 'test_attr_1' } );
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('No entries to show (filtered from %s total entries)', $total_number_of_patrons), 'Searching on a non-searchable attribute returns no results' );

    # clear form
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="clear_search"]')->click();

    # Search on searchable attribute, we expect 2 patrons
    $s->fill_form( { search_patron_filter => 'test_attr_2' } );
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', 2, 2, $total_number_of_patrons), 'Searching on a searchable attribute returns correct results' );

    # clear form
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="clear_search"]')->click();

    $s->fill_form( { search_patron_filter => 'test_attr_3' } ); # Terms must be split
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', 2, 2, $total_number_of_patrons), 'Searching on a searchable attribute returns correct results' );

    # clear form
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="clear_search"]')->click();

    # Search on searchable attribute as specific field, we expect 2 patrons
    $s->fill_form( { search_patron_filter => 'test_attr_4' } );
    $driver->find_element('//form[@id="patron_search_form"]//*[@id="searchfieldstype_filter"]//option[@value="_ATTR_'.$attribute_type_searchable_not_default->code.'"]')->click();
    $s->submit_form;
    sleep $DT_delay && $s->wait_for_ajax;

    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', 2, 2, $total_number_of_patrons), 'Searching on a searchable attribute as a specific field returns correct results' );

    # Refine search and search for test_patron in all the data using the DT global search
    # No change in result expected, still 2 patrons
    $s->driver->find_element('//*[@id="'.$table_id.'_filter"]//input')->send_keys('test_patron');
    sleep $DT_delay && $s->wait_for_ajax;
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', 2, 2, $total_number_of_patrons), 'Refining with DataTables search works to further filter the original query' );

    # Adding the surname of the first patron in the "Name" column
    # We expect only 1 result
    $s->driver->find_element('//table[@id="'.$table_id.'"]//input[@placeholder="Name search"]')->send_keys($patrons[0]->surname);
    sleep $DT_delay && $s->wait_for_ajax;
    is( $driver->find_element('//div[@id="'.$table_id.'_info"]')->get_text, sprintf('Showing 1 to %s of %s entries (filtered from %s total entries)', 1, 1, $total_number_of_patrons), 'Refining with header filters works to further filter the original query' );

    subtest 'remember_search' => sub {

        plan tests => 7;

        C4::Context->set_preference( 'PatronsPerPage', 5 );
        $driver->get( $base_url . "/members/members-home.pl" );
        $s->fill_form( { search_patron_filter => 'test_patron' } );
        $s->submit_form;
        sleep $DT_delay && $s->wait_for_ajax;
        my $patron_selected_text = $driver->find_element('//div[@id="table_search_selections"]/span')->get_text;
        is( $patron_selected_text, "", "Patrons selected is not displayed" );

        my @checkboxes = $driver->find_elements(
            '//input[@type="checkbox"][@name="borrowernumber"]');
        $checkboxes[2]->click;
        $patron_selected_text = $driver->find_element('//div[@id="table_search_selections"]/span')->get_text;
        is( $patron_selected_text, "Patrons selected: 1", "One patron selected" );

        $checkboxes[4]->click;
        $patron_selected_text = $driver->find_element('//div[@id="table_search_selections"]/span')->get_text;
        is( $patron_selected_text, "Patrons selected: 2", "Two patrons are selected" );

        $driver->find_element('//*[@id="memberresultst_next"]')->click;
        sleep $DT_delay && $s->wait_for_ajax;
        @checkboxes = $driver->find_elements(
            '//input[@type="checkbox"][@name="borrowernumber"]');
        $checkboxes[0]->click;
        $patron_selected_text = $driver->find_element('//div[@id="table_search_selections"]/span')->get_text;
        is( $patron_selected_text, "Patrons selected: 3", "Three patrons are selected" );

        # Perform another search
        $driver->get( $base_url . "/members/members-home.pl" );
        $s->fill_form( { search_patron_filter => 'test_patron' } );
        $s->submit_form;
        sleep $DT_delay && $s->wait_for_ajax;
        $patron_selected_text = $driver->find_element('//div[@id="table_search_selections"]/span')->get_text;
        is( $patron_selected_text, "Patrons selected: 3", "Three patrons still selected" );

        $driver->find_element('//*[@id="patronlist-menu"]')->click;
        $driver->find_element('//a[@class="patron-list-add"]')->click;
        my $patron_list_name = "my new list";
        $driver->find_element('//input[@id="new_patron_list"]')->send_keys($patron_list_name);
        $driver->find_element('//button[@id="add_to_patron_list_submit"]')->click;
        sleep $DT_delay && $s->wait_for_ajax;
        is( $driver->find_element('//*[@id="patron_list_dialog"]')->get_text, "Added 3 patrons to $patron_list_name." );
        my $patron_list = $schema->resultset('PatronList')->search({ name => $patron_list_name })->next;
        is( $schema->resultset('PatronListPatron')->search({ patron_list_id => $patron_list->patron_list_id })->count, 3 );

        $patron_list->delete;
    };

    subtest 'filter by date of birth' => sub {
        plan tests => 7;

        C4::Context->set_preference( 'dateformat', 'metric' );

        # We have a patron with date of birth=1980-06-17 => formatted as 17/06/1980

        $driver->get( $base_url . "/members/members-home.pl" );
        $s->fill_form( { search_patron_filter => 'test_patron' } );
        $s->submit_form;
        sleep $DT_delay && $s->wait_for_ajax;

        $s->show_all_entries( '//div[@id="' . $table_id . '_wrapper"]' );
        my $dob_search_filter =
            $s->driver->find_element( '//table[@id="' . $table_id . '"]//input[@placeholder="Date of birth search"]' );

        $dob_search_filter->send_keys('1980');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 1, 'search by correct year shows the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('1986');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 0, 'search by incorrect year does not show the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('1980-06');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 1, 'search by correct year-month shows the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('1980-06-17');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 1, 'search by correct full iso date shows the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('1986-06-17');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 0, 'search by incorrect full iso date does not show the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('17/06/1980');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 1, 'search by correct full formatted date shows the patron' );
        $dob_search_filter->clear;

        $dob_search_filter->send_keys('17/06/1986');
        sleep $DT_delay && $s->wait_for_ajax;
        is( is_patron_shown($patron_27), 0, 'search by incorrect full formatted date does not show the patron' );
        $dob_search_filter->clear;
    };

    $driver->quit();
};

sub is_patron_shown {
    my ($patron) = @_;

    my @checkboxes = $driver->find_elements('//input[@type="checkbox"][@name="borrowernumber"]');
    return scalar( grep { $_->get_value == $patron->borrowernumber } @checkboxes );
}
