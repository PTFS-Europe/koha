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

use Modern::Perl;
use CGI;

use C4::Auth;
use C4::Context;
use C4::Output;

use Koha::Database;

my $cgi = CGI->new();
my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'admin/transcode.tt',
        query           => $cgi,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $schema = Koha::Database->new()->schema();

my $function = $cgi->param('op');
$function ||= 'display';

my @transcodes = $schema->resultset('CashTranscode')->search( undef, { order_by => { -asc => 'code', }});

my @taxrates = $schema->resultset('AuthorisedValue')->search( { category => 'TaxRate', });
my @groups = $schema->resultset('AuthorisedValue')->search( { category => 'PaymentGroup', });

$template->param(
    transcodes => \@transcodes,
    groups     => \@groups,
    taxrates   => \@taxrates,
    display    => 1,
);
output_html_with_http_headers( $cgi, $cookie, $template->output );
