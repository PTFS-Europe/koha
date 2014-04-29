#!/usr/bin/perl

# Copyright (c) 2013 Mark Gavillet & PTFS Europe
# Copyright (c) 2014 PTFS Europe Ltd
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

use strict;
use warnings;
use C4::Auth;
use C4::Output;
use CGI;
use C4::Members qw(GetMemberDetails);
use C4::ILL
  qw(DeleteILLRequest UpdateILLRequest GetILLRequest GetILLAuthValues);
use C4::Context;

my $input = CGI->new();

my $requestid = $input->param('requestid');
my $op        = $input->param('op');
$op //= q{};

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'ill/illrequest-details.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { ill => 1 },
    }
);

if ( $op eq 'delconfirmed' ) {
    DeleteILLRequest($requestid);
    $template->param( deleted => 1 );
}

if ( $op =~ m/^request_(book|thesis|journal|other|conference)$/ ) {
    my $ill_req = {
        requestid         => $requestid,
        biblionumber      => $input->param('biblionumber'),
        status            => $input->param('status'),
        title             => $input->param('title'),
        author            => $input->param('author'),
        journal_title     => $input->param('journal_title'),
        publisher         => $input->param('publisher'),
        issn              => $input->param('issn'),
        year              => $input->param('year'),
        season            => $input->param('season'),
        month             => $input->param('month'),
        day               => $input->param('day'),
        volume            => $input->param('volume'),
        part              => $input->param('part'),
        issue             => $input->param('issue'),
        special_issue     => $input->param('special_issue'),
        article_title     => $input->param('article_title'),
        author_names      => $input->param('author_names'),
        pages             => $input->param('pages'),
        notes             => $input->param('notes'),
        conference_title  => $input->param('conference_title'),
        conference_author => $input->param('conference_author'),
        conference_venue  => $input->param('conference_venue'),
        conference_date   => $input->param('conference_date'),
        isbn              => $input->param('isbn'),
        edition           => $input->param('edition'),
        chapter_title     => $input->param('chapter_title'),
        composer          => $input->param('composer'),
        ismn              => $input->param('ismn'),
        university        => $input->param('university'),
        dissertation      => $input->param('dissertation'),
        scale             => $input->param('scale'),
        shelfmark         => $input->param('shelfmark'),
        commercial_use    => $input->param('commercial_use'),
        needed_by         => $input->param('needed_by'),
        local1            => $input->param('local1'),
        local2            => $input->param('local2'),
        local3            => $input->param('local3'),
    };

    UpdateILLRequest($ill_req);
    $template->param( updated => 1 );
}

my $illrequest = GetILLRequest($requestid);

my $illstatuses = GetILLAuthValues('ILLSTATUS');

my $ill_prefix = C4::Context->preference('ILLRequestPrefix');

my $borrower = GetMemberDetails( $illrequest->{borrowernumber} );

$template->param(
    ILLRequest   => $illrequest,
    ill          => 1,
    illstatuses  => $illstatuses,
    ill_prefix   => $ill_prefix,
    borrowername => "$borrower->{showname} $borrower->{surname}",
    op           => $op,
    local1       => C4::Context->preference('ILLLocalField1'),
    local2       => C4::Context->preference('ILLLocalField2'),
    local3       => C4::Context->preference('ILLLocalField3'),
);
output_html_with_http_headers( $input, $cookie, $template->output );
