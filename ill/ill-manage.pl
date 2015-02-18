#!/usr/bin/perl

# Copyright 2012 Mark Gavillet & PTFS Europe
# Copyright 2014 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use CGI;

use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Output;
use C4::Branch;
use Koha::Borrowers;
use Koha::ILLRequests;
use URI::Escape;

my $cgi = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => 'ill/ill-manage.tt',
        query         => $cgi,
        type          => 'intranet',
        flagsrequired => { ill => 1 },
    }
);

my $tabs = {
    view        => "View",
    edit        => "Edit",
    progress    => "Progress",
};
if (C4::Context->preference('GenericILLModule')) {
    $tabs->{generic_ill} = "Generic ILL";
}

my $op = $cgi->param('op');
my $rq = $cgi->param('rq');
my $here = "/cgi-bin/koha/ill/ill-manage.pl";
my $tab_url = $here . "?rq=" . $rq . "&op=";

if ( $rq and $op eq 'view' ) {
    my $request = @{Koha::ILLRequests->new()->retrieve_ill_request($rq)}[0];
    $template->param(
        ill   => $request->getSummary,
        title => $tabs->{$op},
    );

} elsif ( $rq and $op eq 'edit' ) {
    my $request = @{Koha::ILLRequests->new()->retrieve_ill_request($rq)}[0];
    $template->param(
        ill   => $request->getForEditing,
        title => $tabs->{$op},
        forward => "update",
    );

} elsif ( $rq and $op eq 'progress' ) {
    my $request = @{Koha::ILLRequests->new()->retrieve_ill_request($rq)}[0];
    $template->param(
        ill     => $request->checkSimpleAvailability,
        title   => "Availability",
        forward => 'price',
    );

} elsif ( $rq and $op eq 'price' ) {
    my $request = @{Koha::ILLRequests->new()->retrieve_ill_request($rq)}[0];
    my $coordinates = {
                       format  => $cgi->param('format'),
                       speed   => $cgi->param('speed'),
                       quality => $cgi->param('quality'),
                       };
    $template->param(
        ill         => $request->calculatePrice($coordinates),
        title       => "Prices",
        coordinates => $coordinates,
    );

} elsif ( $rq and $op eq 'update' ) {
    # We should have a complete set of Request properties / attributes, so we
    # should just be able to push to DB?
    my $request = @{Koha::ILLRequests->new()->retrieve_ill_request($rq)}[0];
    $request->editStatus(\%{$cgi->Vars});
    $template->param(
        ill   => $request->getSummary,
        title => $tabs->{view},
    );

} else {
    die("Unexpected combination of parameters!")
}

$template->param(
    op      => $op,
    rq      => $rq,
    tab_url => $tab_url,
    tabs    => $tabs,
);

output_html_with_http_headers( $cgi, $cookie, $template->output );
