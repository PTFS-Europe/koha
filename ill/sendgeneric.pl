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
use C4::ILL::Mailer;

my $q = CGI->new;

my $request_id     = $q->param('requestid');
my $send_confirmed = $q->param('cmd');
my $email_address  = $q->param('email_address');
my $msg_text       = $q->param('msg_text');
my $notes          = $q->param('notes');

my $next_template = 'ill/generic_request.tt';
my $req           = GetILLRequest($request_id);
$req->{display_title} = $req->{title};
if ( $req->{author_editor} ) {
    $req->{display_title} .= " / $req->{author_editor}";
}

if ($send_confirmed) {
    my $text = $msg_text;
    if ($notes) {
        $text .= " $notes";
    }
    my $mailer = C4::ILL::Mailer->new();

    # TODO send should return a status
    $mailer->send( { content => $text, recepient => $email_address, } );

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
