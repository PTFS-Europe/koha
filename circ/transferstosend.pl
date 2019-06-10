#!/usr/bin/perl

# Copyright 2019 PTFS-Europe Ltd.
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

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Context;
use C4::Auth;
use C4::Output;

use Koha::DateUtils;

my $input      = new CGI;
my $itemnumber = $input->param('itemnumber');

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "circ/transferstosend.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

# set the userenv branch
my $branchcode = C4::Context->userenv->{'branch'};

# transfers prompted by stockrotation
my @transfers = Koha::Libraries->search(
    {
        'branchtransfers_tobranches.frombranch'  => $branchcode,
        'branchtransfers_tobranches.datesent'    => { '!=' => undef },
        'branchtransfers_tobranches.datearrived' => undef,
        'branchtransfers_tobranches.comments' =>
          [ "StockrotationAdvance", "StockrotationRepatriation" ]
    },
    {
        prefetch => 'branchtransfers_tobranches',
        order_by => 'branchtransfers_tobranches.tobranch'
    }
);

$template->param(
    branchesloop => \@transfers,
    show_date    => output_pref(
        { dt => dt_from_string, dateformat => 'iso', dateonly => 1 }
    )
);

output_html_with_http_headers $input, $cookie, $template->output;
