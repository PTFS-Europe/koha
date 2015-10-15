#!/usr/bin/perl
#
# Copyright 2015 PTFS Europe
#
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

use strict;
use warnings;

use CGI;

use C4::Auth;
use C4::Branch qw( GetBranchesLoop);
use C4::Koha;
use C4::Context;
use C4::Output;
use Koha::Till;

my $cgi = CGI->new();
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/tills.tt',
        query           => $cgi,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { admin => 'edit_tills' },
    }
);
my $task   = $cgi->param('op') || 'display';
my $tillid = $cgi->param('tillid');            # update/archive
my $dbh    = C4::Context->dbh;

if ( $task eq 'add' ) {
    my $branch         = $cgi->param('branch');
    my $name           = $cgi->param('name');
    my $description    = $cgi->param('description');
    my $starting_float = $cgi->param('starting_float');
}
elsif ( $task eq 'add_form' ) {
    if ($tillid) {
        my $till =
          $dbh->selectrow_hashref( 'select * from cash_till where tillid = ?',
            {}, $tillid );
        $template->param( till => $till );
    }
    $template->param(
        branch_list => GetBranchesLoop(),
        add_form    => 1
    );

}
elsif ( $task eq 'archive' ) {
    if ($tillid) {
        $dbh->do( 'update cash_till set archived = 1 where tillid = ?',
            {}, $tillid );
    }
    $task = 'display';
}
elsif ( $task eq 'unarchive' ) {
    if ($tillid) {
        $dbh->do( 'update cash_till set archived = 0 where tillid = ?',
            {}, $tillid );
    }
    $task = 'display';
}
elsif ( $task eq 'update' ) {
    my $name = $cgi->param('name');
    $name ||= q{};
    my $description = $cgi->param('description');
    $description ||= q{};
    my $branch = $cgi->param('branch');
    my $float  = $cgi->param('starting_float');
    if ($tillid) {
        $dbh->do(
'update cash_till set name = ?, description = ?, branch = ?, starting_float = ? where tillid = ?',
            {}, $name, $description, $branch, $float, $tillid
        );
    }
    else {
        $dbh->do(
'insert into cash_till ( name, description, branch, starting_float ) values ( ?,?,?,? )',
            {}, $name, $description, $branch, $float
        );
    }
    $task = 'display';
}
if ( $task eq 'display' ) {
    my $cash_tills = Koha::Till->get_till_list();

    $template->param( till_list => $cash_tills, );
}

output_html_with_http_headers $cgi, $cookie, $template->output;
