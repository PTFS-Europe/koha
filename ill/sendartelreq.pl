#!/usr/bin/perl
use strict;
use warnings;

# This file is part of Koha.
# Copyright 2013 PTFS-Europe

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

use CGI;
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::ILL qw( GetILLRequest );
use C4::ILL::ARTEmail::Order;
use C4::ILL::ARTEmail::Message;
use C4::ILL::Mailer;

my $q = CGI->new;

my $request_id        = $q->param('requestid');
my @codes             = $q->param('codes');
my $service_code      = $q->param('service_code');
my $format_speed_code = $q->param('format_speed_code');

my $send_confirmed = $q->param('cmd');
my $next_template  = 'ill/arttel_request.tt';

my $req = GetILLRequest($request_id);
if ($service_code) {
    push @codes, $service_code;
}
if ($format_speed_code) {
    push @codes, $format_speed_code;
}
if (@codes) {
    $req->{keyword_codes} = \@codes;
}

$req->{display_title} = $req->{title};    # TODO Elaborate for diff types

if ($send_confirmed) {
    my @ord;
    push @ord, C4::ILL::ARTEmail::Order->new($req);
    my $msg = C4::ILL::ARTEmail::Message->new(@ord);

    my $text   = $msg->output();
    my $mailer = C4::ILL::Mailer->new();

    # TODO send should return a status
    $mailer->send( { content => $text, } );

    #set status to sent
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => $next_template,
        query         => $q,
        type          => 'intranet',
        flagsrequired => { ill => 1 },
    }
);

$template->param(
    req        => $req,
    ill_prefix => C4::Context->preference('ILLRequestPrefix'),
);

output_html_with_http_headers( $q, $cookie, $template->output );
