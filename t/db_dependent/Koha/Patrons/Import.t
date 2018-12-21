#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
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
use Test::More tests => 142;
use Test::Warn;

# To be replaced by t::lib::Mock
use Test::MockModule;
use Koha::Database;

use File::Temp qw(tempfile tempdir);
my $temp_dir = tempdir('Koha_patrons_import_test_XXXX', CLEANUP => 1, TMPDIR => 1);

use t::lib::Mocks;
use t::lib::TestBuilder;
my $builder = t::lib::TestBuilder->new;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

# ########## Tests start here #############################
# Given ... we can use the module
BEGIN { use_ok('Koha::Patrons::Import'); }

my $patrons_import = new_ok('Koha::Patrons::Import');

subtest 'test_methods' => sub {
    plan tests => 1;

    # Given ... we can reach the method(s)
    my @methods = ('import_patrons',
                   'set_attribute_types',
                   'prepare_columns',
                   'set_column_keys',
                   'set_patron_attributes',
                   'check_branch_code',
                   'format_dates',
                  );
    can_ok('Koha::Patrons::Import', @methods);
};

subtest 'test_attributes' => sub {
    plan tests => 1;

    my @attributes = ('today_iso', 'text_csv');
    can_ok('Koha::Patrons::Import', @attributes);
};

# Tests for Koha::Patrons::Import::import_patrons()
# Given ... nothing much. When ... Then ...
my $result;
warning_is { $result = $patrons_import->import_patrons(undef) }
           { carped => 'No file handle passed in!' },
           " Koha::Patrons::Import->import_patrons carps if no file handle is passed";
is($result, undef, 'Got the expected undef from import_patrons with nothing much');

# Given ... some params but no file handle.
my $params_0 = { some_stuff => 'random stuff', };

# When ... Then ...
my $result_0;
warning_is { $result_0 = $patrons_import->import_patrons($params_0) }
           { carped => 'No file handle passed in!' },
           " Koha::Patrons::Import->import_patrons carps if no file handle is passed";
is($result_0, undef, 'Got the expected undef from import_patrons with no file handle');

# Given ... a file handle to file with headers only.
t::lib::Mocks::mock_preference('ExtendedPatronAttributes', 0);
t::lib::Mocks::mock_preference('dateformat', 'us');


my $csv_headers  = 'cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,address,address2,city,state,zipcode,country,email,phone,mobile,fax,dateofbirth,branchcode,categorycode,dateenrolled,dateexpiry,userid,password';
my $res_header   = 'cardnumber, surname, firstname, title, othernames, initials, streetnumber, streettype, address, address2, city, state, zipcode, country, email, phone, mobile, fax, dateofbirth, branchcode, categorycode, dateenrolled, dateexpiry, userid, password';
my $csv_one_line = '1000,Nancy,Jenkins,Dr,,NJ,78,Circle,Bunting,El Paso,Henderson,Texas,79984,United States,ajenkins0@sourceforge.net,7-(388)559-6763,3-(373)151-4471,8-(509)286-4001,10/16/1965,CPL,PT,12/28/2014,07/01/2015,jjenkins0,DPQILy';
my $csv_one_line_a = '1001,Nancy,Jenkins,Dr,,NJ,78,Circle,Bunting,El Paso,Henderson,Texas,79984,United States,ajenkins0@sourceforge.net,7-(388)559-6763,3-(373)151-4471,8-(509)286-4001,10/16/1965,CPL,PT,12/28/2014,07/01/2015,jjenkins0,DPQILy';

my $filename_1 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_1, "<", $filename_1) or die "cannot open < $filename_1: $!";
my $params_1 = { file => $handle_1, };

# When ...
my $result_1 = $patrons_import->import_patrons($params_1);

# Then ...
is($result_1->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons with no matchpoint defined');
is(scalar @{$result_1->{errors}}, 0, 'Got the expected 0 size error array from import_patrons with no matchpoint defined');

is($result_1->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons with no matchpoint defined');
is($result_1->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with no matchpoint defined');
is($result_1->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with no matchpoint defined');

is($result_1->{feedback}->[1]->{feedback}, 1, 'Got the expected second feedback from import_patrons with no matchpoint defined');
is($result_1->{feedback}->[1]->{name}, 'lastimported', 'Got the expected last imported name from import_patrons with no matchpoint defined');
like($result_1->{feedback}->[1]->{value}, qr/^Nancy \/ \d+/, 'Got the expected second header row value from import_patrons with no matchpoint defined');

is($result_1->{imported}, 1, 'Got the expected 1 imported result from import_patrons with no matchpoint defined');
is($result_1->{invalid}, 0, 'Got the expected 0 invalid result from import_patrons with no matchpoint defined');
is($result_1->{overwritten}, 0, 'Got the expected 0 overwritten result from import_patrons with no matchpoint defined');

# Given ... a valid file handle, a bad matchpoint resulting in invalid card number
my $filename_2 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_2, "<", $filename_2) or die "cannot open < $filename_2: $!";
my $params_2 = { file => $handle_2, matchpoint => 'SHOW_BCODE', };

# When ...
my $result_2 = $patrons_import->import_patrons($params_2);

# Then ...
is($result_2->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons with invalid card number');
is($result_2->{errors}->[0]->{borrowernumber}, undef, 'Got the expected undef borrower number from import patrons with invalid card number');
is($result_2->{errors}->[0]->{cardnumber}, 1000, 'Got the expected 1000 card number from import patrons with invalid card number');
is($result_2->{errors}->[0]->{invalid_cardnumber}, 1, 'Got the expected invalid card number from import patrons with invalid card number');

is($result_2->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons with invalid card number');
is($result_2->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with invalid card number');
is($result_2->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with invalid card number');

is($result_2->{imported}, 0, 'Got the expected 0 imported result from import_patrons with invalid card number');
is($result_2->{invalid}, 1, 'Got the expected 1 invalid result from import_patrons with invalid card number');
is($result_2->{overwritten}, 0, 'Got the expected 0 overwritten result from import_patrons with invalid card number');

# Given ... valid file handle, good matchpoint that matches should not overwrite when not set.
my $filename_3 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_3, "<", $filename_3) or die "cannot open < $filename_3: $!";
my $params_3 = { file => $handle_3, matchpoint => 'cardnumber', };

# When ...
my $result_3 = $patrons_import->import_patrons($params_3);

# Then ...
is($result_3->{already_in_db}, 1, 'Got the expected 1 already_in_db from import_patrons with duplicate userid');
is($result_3->{errors}->[0]->{duplicate_userid}, undef, 'No duplicate userid error from import patrons with duplicate userid (it is our own)');
is($result_3->{errors}->[0]->{userid}, undef, 'No duplicate userid error from import patrons with duplicate userid (it is our own)');

is($result_3->{feedback}->[0]->{feedback}, 1, 'Got 1 expected feedback from import_patrons that matched but not overwritten');
is($result_3->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with duplicate userid');
is($result_3->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with duplicate userid');

is($result_3->{imported}, 0, 'Got the expected 0 imported result from import_patrons');
is($result_3->{invalid}, 0, 'Got the expected 0 invalid result from import_patrons');
is($result_3->{overwritten}, 0, 'Got the expected 0 overwritten result from import_patrons that matched');

# Given ... valid file handle, good matchpoint that matches should overwrite when set.
my $filename_3a = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_3a, "<", $filename_3a) or die "cannot open < $filename_3: $!";
my $params_3a = { file => $handle_3a, matchpoint => 'cardnumber', overwrite_cardnumber => 1};

# When ...
my $result_3a = $patrons_import->import_patrons($params_3a);

# Then ...
is($result_3a->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons when matched and overwrite set');
is($result_3a->{errors}->[0]->{duplicate_userid}, undef, 'No duplicate userid error from import patrons with duplicate userid (it is our own)');
is($result_3a->{errors}->[0]->{userid}, undef, 'No duplicate userid error from import patrons with duplicate userid (it is our own)');

is($result_3a->{feedback}->[0]->{feedback}, 1, 'Got 1 expected feedback from import_patrons that matched and overwritten');
is($result_3a->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with duplicate userid');
is($result_3a->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with duplicate userid');

is($result_3a->{imported}, 0, 'Got the expected 0 imported result from import_patrons');
is($result_3a->{invalid}, 0, 'Got the expected 0 invalid result from import_patrons');
is($result_3a->{overwritten}, 1, 'Got the expected 1 overwritten result from import_patrons that matched');

# Given ... valid file handle, good matchpoint that does not match and conflicting userid.
my $filename_3b = make_csv($temp_dir, $csv_headers, $csv_one_line_a);
open(my $handle_3b, "<", $filename_3b) or die "cannot open < $filename_3: $!";
my $params_3b = { file => $handle_3b, matchpoint => 'cardnumber', };

# When ...
my $result_3b = $patrons_import->import_patrons($params_3b);

# Then ...
is($result_3b->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons with duplicate userid');
is($result_3b->{errors}->[0]->{duplicate_userid}, 1, 'Got the expected duplicate userid error from import patrons with duplicate userid');
is($result_3b->{errors}->[0]->{userid}, 'jjenkins0', 'Got the expected userid error from import patrons with duplicate userid');

is($result_3b->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons with duplicate userid');
is($result_3b->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with duplicate userid');
is($result_3b->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with duplicate userid');

is($result_3b->{imported}, 0, 'Got the expected 0 imported result from import_patrons with duplicate userid');
is($result_3b->{invalid}, 1, 'Got the expected 1 invalid result from import_patrons with duplicate userid');
is($result_3b->{overwritten}, 0, 'Got the expected 0 overwritten result from import_patrons with duplicate userid');

# Given ... a new input and mocked C4::Context
t::lib::Mocks::mock_preference('ExtendedPatronAttributes', 1);

my $new_input_line = '1001,Donna,Sullivan,Mrs,Henry,DS,59,Court,Burrows,Reading,Salt Lake City,Pennsylvania,19605,United States,hsullivan1@purevolume.com,3-(864)009-3006,7-(291)885-8423,1-(879)095-5038,09/19/1970,LPL,PT,03/04/2015,07/01/2015,hsullivan1,8j6P6Dmap';
my $filename_4 = make_csv($temp_dir, $csv_headers, $new_input_line);
open(my $handle_4, "<", $filename_4) or die "cannot open < $filename_4: $!";
my $params_4 = { file => $handle_4, matchpoint => 'SHOW_BCODE', };

# When ...
my $result_4 = $patrons_import->import_patrons($params_4);

# Then ...
is($result_4->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons with extended user');
is(scalar @{$result_4->{errors}}, 0, 'Got the expected 0 size error array from import_patrons with extended user');

is($result_4->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons with extended user');
is($result_4->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons with extended user');
is($result_4->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons with extended user');

is($result_4->{feedback}->[1]->{feedback}, 1, 'Got the expected second feedback from import_patrons with extended user');
is($result_4->{feedback}->[1]->{name}, 'attribute string', 'Got the expected attribute string from import_patrons with extended user');
is($result_4->{feedback}->[1]->{value}, '', 'Got the expected second feedback value from import_patrons with extended user');

is($result_4->{feedback}->[2]->{feedback}, 1, 'Got the expected third feedback from import_patrons with extended user');
is($result_4->{feedback}->[2]->{name}, 'lastimported', 'Got the expected last imported name from import_patrons with extended user');
like($result_4->{feedback}->[2]->{value}, qr/^Donna \/ \d+/, 'Got the expected third feedback value from import_patrons with extended user');

is($result_4->{imported}, 1, 'Got the expected 1 imported result from import_patrons with extended user');
is($result_4->{invalid}, 0, 'Got the expected 0 invalid result from import_patrons with extended user');
is($result_4->{overwritten}, 0, 'Got the expected 0 overwritten result from import_patrons with extended user');

t::lib::Mocks::mock_preference('ExtendedPatronAttributes', 0);

# Given ... 3 new inputs. One with no branch code, one with unexpected branch code.
my $input_no_branch   = '1002,Johnny,Reynolds,Mr,Patricia,JR,12,Hill,Kennedy,Saint Louis,Colorado Springs,Missouri,63131,United States,preynolds2@washington.edu,7-(925)314-9514,0-(315)973-8956,4-(510)556-2323,09/18/1967,,PT,05/07/2015,07/01/2015,preynolds2,K3HiDzl';
my $input_good_branch = '1003,Linda,Richardson,Mr,Kimberly,LR,90,Place,Bayside,Atlanta,Erie,Georgia,31190,United States,krichardson3@pcworld.com,8-(035)185-0387,4-(796)518-3676,3-(644)960-3789,04/13/1954,RPL,PT,06/06/2015,07/01/2015,krichardson3,P3EO0MVRPXbM';
my $input_na_branch   = '1005,Ruth,Greene,Mr,Michael,RG,3,Avenue,Grim,Peoria,Jacksonville,Illinois,61614,United States,mgreene5@seesaa.net,3-(941)565-5752,1-(483)885-8138,4-(979)577-6908,02/09/1957,ZZZ,ST,04/02/2015,07/01/2015,mgreene5,or4ORT6JH';

my $filename_5 = make_csv($temp_dir, $csv_headers, $input_no_branch, $input_good_branch, $input_na_branch);
open(my $handle_5, "<", $filename_5) or die "cannot open < $filename_5: $!";
my $params_5 = { file => $handle_5, matchpoint => 'cardnumber', };

# When ...
my $result_5 = $patrons_import->import_patrons($params_5);

# Then ...
is($result_5->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons for branch tests');

is($result_5->{errors}->[0]->{missing_criticals}->[0]->{borrowernumber}, 'UNDEF', 'Got the expected undef borrower number error from import patrons for branch tests');
is($result_5->{errors}->[0]->{missing_criticals}->[0]->{key}, 'branchcode', 'Got the expected branch code key from import patrons for branch tests');
is($result_5->{errors}->[0]->{missing_criticals}->[0]->{line}, 2, 'Got the expected 2 line number error from import patrons for branch tests');
is($result_5->{errors}->[0]->{missing_criticals}->[0]->{lineraw}, $input_no_branch."\r\n", 'Got the expected lineraw error from import patrons for branch tests');
is($result_5->{errors}->[0]->{missing_criticals}->[0]->{surname}, 'Johnny', 'Got the expected surname error from import patrons for branch tests');

is($result_5->{errors}->[1]->{missing_criticals}->[0]->{borrowernumber}, 'UNDEF', 'Got the expected undef borrower number error from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{branch_map}, 1, 'Got the expected 1 branchmap error from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{key}, 'branchcode', 'Got the expected branch code key from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{line}, 4, 'Got the expected 4 line number error from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{lineraw}, $input_na_branch."\r\n", 'Got the expected lineraw error from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{surname}, 'Ruth', 'Got the expected surname error from import patrons for branch tests');
is($result_5->{errors}->[1]->{missing_criticals}->[0]->{value}, 'ZZZ', 'Got the expected ZZZ value error from import patrons for branch tests');

is($result_5->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for branch tests');
is($result_5->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons for branch tests');
is($result_5->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons for branch tests');

is($result_5->{feedback}->[1]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for branch tests');
is($result_5->{feedback}->[1]->{name}, 'lastimported', 'Got the expected lastimported name from import_patrons for branch tests');
like($result_5->{feedback}->[1]->{value},  qr/^Linda \/ \d+/, 'Got the expected last imported value from import_patrons with for branch tests');

is($result_5->{imported}, 1, 'Got the expected 1 imported result from import patrons for branch tests');
is($result_5->{invalid}, 2, 'Got the expected 2 invalid result from import patrons for branch tests');
is($result_5->{overwritten}, 0, 'Got the expected 0 overwritten result from import patrons for branch tests');

# Given ... 3 new inputs. One with no category code, one with unexpected category code.
my $input_no_category   = '1006,Christina,Olson,Rev,Kimberly,CO,8,Avenue,Northridge,Lexington,Wilmington,Kentucky,40510,United States,kolson6@dropbox.com,7-(810)636-6048,1-(052)012-8984,8-(567)232-7818,03/26/1952,FFL,,09/07/2014,01/07/2015,kolson6,x5D3qGbLlptx';
my $input_good_category = '1007,Peter,Peters,Mrs,Lawrence,PP,6,Trail,South,Oklahoma City,Topeka,Oklahoma,73135,United States,lpeters7@bandcamp.com,5-(992)205-9318,0-(732)586-9365,3-(448)146-7936,08/16/1983,PVL,T,03/24/2015,07/01/2015,lpeters7,Z19BrQ4';
my $input_na_category   = '1008,Emily,Richards,Ms,Judy,ER,73,Way,Kedzie,Fort Wayne,Phoenix,Indiana,46825,United States,jrichards8@arstechnica.com,5-(266)658-8957,3-(550)500-9107,7-(816)675-9822,08/09/1984,FFL,ZZ,11/09/2014,07/01/2015,jrichards8,D5PvU6H2R';

my $filename_6 = make_csv($temp_dir, $csv_headers, $input_no_category, $input_good_category, $input_na_category);
open(my $handle_6, "<", $filename_6) or die "cannot open < $filename_6: $!";
my $params_6 = { file => $handle_6, matchpoint => 'cardnumber', };

# When ...
my $result_6 = $patrons_import->import_patrons($params_6);

# Then ...
is($result_6->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons for category tests');

is($result_6->{errors}->[0]->{missing_criticals}->[0]->{borrowernumber}, 'UNDEF', 'Got the expected undef borrower number error from import patrons for category tests');
is($result_6->{errors}->[0]->{missing_criticals}->[0]->{key}, 'categorycode', 'Got the expected category code key from import patrons for category tests');
is($result_6->{errors}->[0]->{missing_criticals}->[0]->{line}, 2, 'Got the expected 2 line number error from import patrons for category tests');
is($result_6->{errors}->[0]->{missing_criticals}->[0]->{lineraw}, $input_no_category."\r\n", 'Got the expected lineraw error from import patrons for category tests');
is($result_6->{errors}->[0]->{missing_criticals}->[0]->{surname}, 'Christina', 'Got the expected surname error from import patrons for category tests');

is($result_6->{errors}->[1]->{missing_criticals}->[0]->{borrowernumber}, 'UNDEF', 'Got the expected undef borrower number error from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{category_map}, 1, 'Got the expected 1 category_map error from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{key}, 'categorycode', 'Got the expected category code key from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{line}, 4, 'Got the expected 4 line number error from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{lineraw}, $input_na_category."\r\n", 'Got the expected lineraw error from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{surname}, 'Emily', 'Got the expected surname error from import patrons for category tests');
is($result_6->{errors}->[1]->{missing_criticals}->[0]->{value}, 'ZZ', 'Got the expected ZZ value error from import patrons for category tests');

is($result_6->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for category tests');
is($result_6->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons for category tests');
is($result_6->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons for category tests');

is($result_6->{feedback}->[1]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for category tests');
is($result_6->{feedback}->[1]->{name}, 'lastimported', 'Got the expected lastimported name from import_patrons for category tests');
like($result_6->{feedback}->[1]->{value},  qr/^Peter \/ \d+/, 'Got the expected last imported value from import_patrons with for category tests');

is($result_6->{imported}, 1, 'Got the expected 1 imported result from import patrons for category tests');
is($result_6->{invalid}, 2, 'Got the expected 2 invalid result from import patrons for category tests');
is($result_6->{overwritten}, 0, 'Got the expected 0 overwritten result from import patrons for category tests');

# Given ... 2 new inputs. One without dateofbirth, dateenrolled and dateexpiry values.
my $input_complete = '1009,Christina,Harris,Dr,Philip,CH,99,Street,Grayhawk,Baton Rouge,Dallas,Louisiana,70810,United States,pharris9@hp.com,9-(317)603-5513,7-(005)062-7593,8-(349)134-1627,06/19/1969,IPT,PT,04/09/2015,07/01/2015,pharris9,NcAhcvvnB';
my $input_no_date  = '1010,Ralph,Warren,Ms,Linda,RW,6,Way,Barby,Orlando,Albany,Florida,32803,United States,lwarrena@multiply.com,7-(579)753-7752,6-(847)086-7566,9-(122)729-8226,26/01/2001,LPL,T,25/01/2001,24/01/2001,lwarrena,tJ56RD4uV';

my $filename_7 = make_csv($temp_dir, $csv_headers, $input_complete, $input_no_date);
open(my $handle_7, "<", $filename_7) or die "cannot open < $filename_7: $!";
my $params_7 = { file => $handle_7, matchpoint => 'cardnumber', };

# When ...
my $result_7 = $patrons_import->import_patrons($params_7);

# Then ...
is($result_7->{already_in_db}, 0, 'Got the expected 0 already_in_db from import_patrons for dates tests');
is(scalar @{$result_7->{errors}}, 1, 'Got the expected 1 error array size from import_patrons for dates tests');
is(scalar @{$result_7->{errors}->[0]->{missing_criticals}}, 3, 'Got the expected 3 missing critical errors from import_patrons for dates tests');

is($result_7->{errors}->[0]->{missing_criticals}->[0]->{bad_date}, 1, 'Got the expected 1 bad_date error from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[0]->{borrowernumber}, 'UNDEF', 'Got the expected undef borrower number error from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[0]->{key}, 'dateofbirth', 'Got the expected dateofbirth key from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[0]->{line}, 3, 'Got the expected 2 line number error from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[0]->{lineraw}, $input_no_date."\r\n", 'Got the expected lineraw error from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[0]->{surname}, 'Ralph', 'Got the expected surname error from import patrons for dates tests');

is($result_7->{errors}->[0]->{missing_criticals}->[1]->{key}, 'dateenrolled', 'Got the expected dateenrolled key from import patrons for dates tests');
is($result_7->{errors}->[0]->{missing_criticals}->[2]->{key}, 'dateexpiry', 'Got the expected dateexpiry key from import patrons for dates tests');

is(scalar @{$result_7->{feedback}}, 2, 'Got the expected 2 feedback from import patrons for dates tests');
is($result_7->{feedback}->[0]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for dates tests');
is($result_7->{feedback}->[0]->{name}, 'headerrow', 'Got the expected header row name from import_patrons for dates tests');
is($result_7->{feedback}->[0]->{value}, $res_header, 'Got the expected header row value from import_patrons for dates tests');

is($result_7->{feedback}->[1]->{feedback}, 1, 'Got the expected 1 feedback from import_patrons for dates tests');
is($result_7->{feedback}->[1]->{name}, 'lastimported', 'Got the expected lastimported from import_patrons for dates tests');
like($result_7->{feedback}->[1]->{value}, qr/^Christina \/ \d+/, 'Got the expected lastimported value from import_patrons for dates tests');

is($result_7->{imported}, 1, 'Got the expected 1 imported result from import patrons for dates tests');
is($result_7->{invalid}, 1, 'Got the expected 1 invalid result from import patrons for dates tests');
is($result_7->{overwritten}, 0, 'Got the expected 0 overwritten result from import patrons for dates tests');

subtest 'test_prepare_columns' => sub {
    plan tests => 16;

    # Given ... no header row
    my %csvkeycol_0;
    my @errors_0;

    # When ...
    my @csvcolumns_0 = $patrons_import->prepare_columns({headerrow => undef, keycol => \%csvkeycol_0, errors => \@errors_0, });

    # Then ...
    is(scalar @csvcolumns_0, 0, 'Got the expected empty column array from prepare columns with no header row');

    is(scalar @errors_0, 1, 'Got the expected 1 entry in error array from prepare columns with no header row');
    is($errors_0[0]->{badheader}, 1, 'Got the expected 1 badheader from prepare columns with no header row');
    is($errors_0[0]->{line}, 1, 'Got the expected 1 line from prepare columns with no header row');
    is($errors_0[0]->{lineraw}, undef, 'Got the expected undef lineraw from prepare columns with no header row');

    # Given ... a good header row with plenty of whitespaces
    my $headerrow_1 = 'a,    b ,        c,  ,   d';
    my %csvkeycol_1;
    my @errors_1;

    # When ...
    my @csvcolumns_1 = $patrons_import->prepare_columns({headerrow => $headerrow_1, keycol => \%csvkeycol_1, errors => \@errors_1, });

    # Then ...
    is(scalar @csvcolumns_1, 5, 'Got the expected 5 column array from prepare columns');
    is($csvcolumns_1[0], 'a', 'Got the expected a header from prepare columns');
    is($csvcolumns_1[1], 'b', 'Got the expected b header from prepare columns');
    is($csvcolumns_1[2], 'c', 'Got the expected c header from prepare columns');
    is($csvcolumns_1[3], '', 'Got the expected empty header from prepare columns');
    is($csvcolumns_1[4], 'd', 'Got the expected d header from prepare columns');

    is($csvkeycol_1{a}, 0, 'Got the expected 0 value for key a from prepare columns hash');
    is($csvkeycol_1{b}, 1, 'Got the expected 1 value for key b from prepare columns hash');
    is($csvkeycol_1{c}, 2, 'Got the expected 2 value for key c from prepare columns hash');
    is($csvkeycol_1{''}, 3, 'Got the expected 3 value for empty string key from prepare columns hash');
    is($csvkeycol_1{d}, 4, 'Got the expected 4 value for key d from prepare columns hash');
};

subtest 'test_set_column_keys' => sub {
    plan tests => 5;

    # Given ... nothing at all
    # When ... Then ...
    my $attr_type_0 = $patrons_import->set_attribute_types(undef);
    is($attr_type_0, undef, 'Got the expected undef attribute type from set attribute types with nothing');

    # Given ... extended but not matchpoint
    my $params_1 = { extended => 1, matchpoint => undef, };

    # When ... Then ...
    my $attr_type_1 = $patrons_import->set_attribute_types($params_1);
    is($attr_type_1, undef, 'Got the expected undef attribute type from set attribute types with no matchpoint');

    # Given ... extended and unexpected matchpoint
    my $params_2 = { extended => 1, matchpoint => 'unexpected', };

    # When ... Then ...
    my $attr_type_2 = $patrons_import->set_attribute_types($params_2);
    is($attr_type_2, undef, 'Got the expected undef attribute type from set attribute types with unexpected matchpoint');

    # Given ...
    my $code_3   = 'SHOW_BCODE';
    my $params_3 = { extended => 1, matchpoint => $code_3, };

    # When ...
    my $attr_type_3 = $patrons_import->set_attribute_types($params_3);

    # Then ...
    isa_ok($attr_type_3, 'C4::Members::AttributeTypes');
    is($attr_type_3->{code}, $code_3, 'Got the expected code attribute type from set attribute types');
};

subtest 'test_set_column_keys' => sub {
    plan tests => 2;

    my @columns = Koha::Patrons->columns;
    # Given ... nothing at all
    # When ... Then ...
    my @columnkeys_0 = $patrons_import->set_column_keys(undef);
    # -1 because we do not want the borrowernumber column
    is(scalar @columnkeys_0, @columns - 1, 'Got the expected array size from set column keys with undef extended');

    # Given ... extended.
    my $extended = 1;

    # When ... Then ...
    my @columnkeys_1 = $patrons_import->set_column_keys($extended);
    is(scalar @columnkeys_1, @columns - 1 + $extended, 'Got the expected array size from set column keys with extended');
};

subtest 'test_set_patron_attributes' => sub {
    plan tests => 13;

    # Given ... nothing at all
    # When ... Then ...
    my $result_0 = $patrons_import->set_patron_attributes(undef, undef, undef);
    is($result_0, undef, 'Got the expected undef from set patron attributes with nothing');

    # Given ... not extended.
    my $extended_1 = 0;

    # When ... Then ...
    my $result_1 = $patrons_import->set_patron_attributes($extended_1, undef, undef);
    is($result_1, undef, 'Got the expected undef from set patron attributes with not extended');

    # Given ... NO patrons attributes
    my $extended_2          = 1;
    my $patron_attributes_2 = undef;
    my @feedback_2;

    # When ...
    my $result_2 = $patrons_import->set_patron_attributes($extended_2, $patron_attributes_2, \@feedback_2);

    # Then ...
    is($result_2, undef, 'Got the expected undef from set patron attributes with no patrons attributes');
    is(scalar @feedback_2, 0, 'Got the expected 0 size feedback array from set patron attributes with no patrons attributes');

    # Given ... some patrons attributes
    my $patron_attributes_3 = "homeroom:1150605,grade:01";
    my @feedback_3;

    # When ...
    my $result_3 = $patrons_import->set_patron_attributes($extended_2, $patron_attributes_3, \@feedback_3);

    # Then ...
    ok($result_3, 'Got some data back from set patron attributes');
    is($result_3->[0]->{code}, 'grade', 'Got the expected first code from set patron attributes');
    is($result_3->[0]->{value}, '01', 'Got the expected first value from set patron attributes');

    is($result_3->[1]->{code}, 'homeroom', 'Got the expected second code from set patron attributes');
    is($result_3->[1]->{value}, 1150605, 'Got the expected second value from set patron attributes');

    is(scalar @feedback_3, 1, 'Got the expected 1 array size from set patron attributes with extended user');
    is($feedback_3[0]->{feedback}, 1, 'Got the expected second feedback from set patron attributes with extended user');
    is($feedback_3[0]->{name}, 'attribute string', 'Got the expected attribute string from set patron attributes with extended user');
    is($feedback_3[0]->{value}, 'homeroom:1150605,grade:01', 'Got the expected feedback value from set patron attributes with extended user');
};

subtest 'test_check_branch_code' => sub {
    plan tests => 11;

    # Given ... no branch code.
    my $borrowerline      = 'some, line';
    my $line_number       = 78;
    my @missing_criticals = ();

    # When ...
    $patrons_import->check_branch_code(undef, $borrowerline, $line_number, \@missing_criticals);

    # Then ...
    is(scalar @missing_criticals, 1, 'Got the expected missing critical array size of 1 from check_branch_code with no branch code');

    is($missing_criticals[0]->{key}, 'branchcode', 'Got the expected branchcode key from check_branch_code with no branch code');
    is($missing_criticals[0]->{line}, $line_number, 'Got the expected line number from check_branch_code with no branch code');
    is($missing_criticals[0]->{lineraw}, $borrowerline, 'Got the expected lineraw value from check_branch_code with no branch code');

    # Given ... unknown branch code
    my $branchcode_1        = 'unexpected';
    my $borrowerline_1      = 'some, line,'.$branchcode_1;
    my $line_number_1       = 79;
    my @missing_criticals_1 = ();

    # When ...
    $patrons_import->check_branch_code($branchcode_1, $borrowerline_1, $line_number_1, \@missing_criticals_1);

    # Then ...
    is(scalar @missing_criticals_1, 1, 'Got the expected missing critical array size of 1 from check_branch_code with unexpected branch code');

    is($missing_criticals_1[0]->{branch_map}, 1, 'Got the expected 1 branch_map from check_branch_code with unexpected branch code');
    is($missing_criticals_1[0]->{key}, 'branchcode', 'Got the expected branchcode key from check_branch_code with unexpected branch code');
    is($missing_criticals_1[0]->{line}, $line_number_1, 'Got the expected line number from check_branch_code with unexpected branch code');
    is($missing_criticals_1[0]->{lineraw}, $borrowerline_1, 'Got the expected lineraw value from check_branch_code with unexpected branch code');
    is($missing_criticals_1[0]->{value}, $branchcode_1, 'Got the expected value from check_branch_code with unexpected branch code');

    # Given ... a known branch code. Relies on database sample data
    my $branchcode_2        = 'FFL';
    my $borrowerline_2      = 'some, line,'.$branchcode_2;
    my $line_number_2       = 80;
    my @missing_criticals_2 = ();

    # When ...
    $patrons_import->check_branch_code($branchcode_2, $borrowerline_2, $line_number_2, \@missing_criticals_2);

    # Then ...
    is(scalar @missing_criticals_2, 0, 'Got the expected missing critical array size of 0 from check_branch_code');
};

subtest 'test_check_borrower_category' => sub {
    plan tests => 11;

    # Given ... no category code.
    my $borrowerline      = 'some, line';
    my $line_number       = 781;
    my @missing_criticals = ();

    # When ...
    $patrons_import->check_borrower_category(undef, $borrowerline, $line_number, \@missing_criticals);

    # Then ...
    is(scalar @missing_criticals, 1, 'Got the expected missing critical array size of 1 from check_branch_code with no category code');

    is($missing_criticals[0]->{key}, 'categorycode', 'Got the expected categorycode key from check_branch_code with no category code');
    is($missing_criticals[0]->{line}, $line_number, 'Got the expected line number from check_branch_code with no category code');
    is($missing_criticals[0]->{lineraw}, $borrowerline, 'Got the expected lineraw value from check_branch_code with no category code');

    # Given ... unknown category code
    my $categorycode_1      = 'unexpected';
    my $borrowerline_1      = 'some, line, line, '.$categorycode_1;
    my $line_number_1       = 791;
    my @missing_criticals_1 = ();

    # When ...
    $patrons_import->check_borrower_category($categorycode_1, $borrowerline_1, $line_number_1, \@missing_criticals_1);

    # Then ...
    is(scalar @missing_criticals_1, 1, 'Got the expected missing critical array size of 1 from check_branch_code with unexpected category code');

    is($missing_criticals_1[0]->{category_map}, 1, 'Got the expected 1 category_map from check_branch_code with unexpected category code');
    is($missing_criticals_1[0]->{key}, 'categorycode', 'Got the expected branchcode key from check_branch_code with unexpected category code');
    is($missing_criticals_1[0]->{line}, $line_number_1, 'Got the expected line number from check_branch_code with unexpected category code');
    is($missing_criticals_1[0]->{lineraw}, $borrowerline_1, 'Got the expected lineraw value from check_branch_code with unexpected category code');
    is($missing_criticals_1[0]->{value}, $categorycode_1, 'Got the expected value from check_branch_code with unexpected category code');

    # Given ... a known category code. Relies on database sample data.
    my $categorycode_2      = 'T';
    my $borrowerline_2      = 'some, line,'.$categorycode_2;
    my $line_number_2       = 801;
    my @missing_criticals_2 = ();

    # When ...
    $patrons_import->check_borrower_category($categorycode_2, $borrowerline_2, $line_number_2, \@missing_criticals_2);

    # Then ...
    is(scalar @missing_criticals_2, 0, 'Got the expected missing critical array size of 0 from check_branch_code');
};

subtest 'test_format_dates' => sub {
    plan tests => 22;

    # Given ... no borrower data.
    my $borrowerline      = 'another line';
    my $line_number       = 987;
    my @missing_criticals = ();
    my %borrower;
    my $params = {borrower => \%borrower, lineraw => $borrowerline, line => $line_number, missing_criticals => \@missing_criticals, };

    # When ...
    $patrons_import->format_dates($params);

    # Then ...
    ok( not(%borrower), 'Got the expected no borrower from format_dates with no dates');
    is(scalar @missing_criticals, 0, 'Got the expected missing critical array size of 0 from format_dates with no dates');

    # Given ... some good dates
    my @missing_criticals_1 = ();
    my $dateofbirth_1  = '2016-05-03';
    my $dateenrolled_1 = '2016-05-04';
    my $dateexpiry_1   = '2016-05-06';
    my $borrower_1     = { dateofbirth => $dateofbirth_1, dateenrolled => $dateenrolled_1, dateexpiry => $dateexpiry_1, };
    my $params_1       = {borrower => $borrower_1, lineraw => $borrowerline, line => $line_number, missing_criticals => \@missing_criticals_1, };

    # When ...
    $patrons_import->format_dates($params_1);

    # Then ...
    is($borrower_1->{dateofbirth}, $dateofbirth_1, 'Got the expected date of birth from format_dates with good dates');
    is($borrower_1->{dateenrolled}, $dateenrolled_1, 'Got the expected date of birth from format_dates with good dates');
    is($borrower_1->{dateexpiry}, $dateexpiry_1, 'Got the expected date of birth from format_dates with good dates');
    is(scalar @missing_criticals_1, 0, 'Got the expected missing critical array size of 0 from check_branch_code with good dates');

    # Given ... some very bad dates
    my @missing_criticals_2 = ();
    my $dateofbirth_2  = '03-2016-05';
    my $dateenrolled_2 = '04-2016-05';
    my $dateexpiry_2   = '06-2016-05';
    my $borrower_2     = { dateofbirth => $dateofbirth_2, dateenrolled => $dateenrolled_2, dateexpiry => $dateexpiry_2, };
    my $params_2       = {borrower => $borrower_2, lineraw => $borrowerline, line => $line_number, missing_criticals => \@missing_criticals_2, };

    # When ...
    $patrons_import->format_dates($params_2);

    # Then ...
    is($borrower_2->{dateofbirth}, '', 'Got the expected empty date of birth from format_dates with bad dates');
    is($borrower_2->{dateenrolled}, '', 'Got the expected emptydate of birth from format_dates with bad dates');
    is($borrower_2->{dateexpiry}, '', 'Got the expected empty date of birth from format_dates with bad dates');

    is(scalar @missing_criticals_2, 3, 'Got the expected missing critical array size of 3 from check_branch_code with bad dates');
    is($missing_criticals_2[0]->{bad_date}, 1, 'Got the expected first bad date flag from check_branch_code with bad dates');
    is($missing_criticals_2[0]->{key}, 'dateofbirth', 'Got the expected dateofbirth key from check_branch_code with bad dates');
    is($missing_criticals_2[0]->{line}, $line_number, 'Got the expected first line from check_branch_code with bad dates');
    is($missing_criticals_2[0]->{lineraw}, $borrowerline, 'Got the expected first lineraw from check_branch_code with bad dates');

    is($missing_criticals_2[1]->{bad_date}, 1, 'Got the expected second bad date flag from check_branch_code with bad dates');
    is($missing_criticals_2[1]->{key}, 'dateenrolled', 'Got the expected dateenrolled key from check_branch_code with bad dates');
    is($missing_criticals_2[1]->{line}, $line_number, 'Got the expected second line from check_branch_code with bad dates');
    is($missing_criticals_2[1]->{lineraw}, $borrowerline, 'Got the expected second lineraw from check_branch_code with bad dates');

    is($missing_criticals_2[2]->{bad_date}, 1, 'Got the expected third bad date flag from check_branch_code with bad dates');
    is($missing_criticals_2[2]->{key}, 'dateexpiry', 'Got the expected dateexpiry key from check_branch_code with bad dates');
    is($missing_criticals_2[2]->{line}, $line_number, 'Got the expected third line from check_branch_code with bad dates');
    is($missing_criticals_2[2]->{lineraw}, $borrowerline, 'Got the expected third lineraw from check_branch_code with bad dates');
};

# ###### Test utility ###########
sub make_csv {
    my ($temp_dir, @lines) = @_;

    my ($fh, $filename) = tempfile( DIR => $temp_dir) or die $!;
    print $fh $_."\r\n" foreach @lines;
    close $fh or die $!;

    return $filename;
}

1;
