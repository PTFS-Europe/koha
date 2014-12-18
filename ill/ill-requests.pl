#!/usr/bin/perl

# Copyright 2013 PTFS-Europe Ltd and Mark Gavillet
# Copyright 2014 PTFS-Europe Ltd
#
# This file is part of Koha.
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
use CGI;
use C4::Auth;
use C4::Output;
use C4::Search qw(GetDistinctValues);
use C4::Context;
use Koha::ILLRequests;

use Data::Dump qw( dump );
sub msg {
    open my $log_fh, '>>', '/home/alex/koha-dev/var/log/dump.log'
      or die "Could not open log: $!";
    print $log_fh @_;
    close $log_fh;
}

my $input = CGI->new;
my $reply = [];
my $type = $input->param('query_type');
my $query = $input->param('query_value');

msg( $query . "\n" );
msg( $type . "\n" );

my ( $template, $borrowernumber, $cookie )
  = get_template_and_user(
                          {
                           template_name => 'ill/ill-requests.tt',
                           query         => $input,
                           type          => 'intranet',
                           flagsrequired => { ill => 1 },
                          }
                         );

$template->param( query_value => $query );
$template->param( query_type => $type );

if ( $type eq 'api' and $query ) {
    $reply = Koha::ILLRequests->new()->search_api($query);

} elsif ( $type eq 'request' and $query ) {
    my $request = Koha::ILLRequests->new()->request($query);
    push @{$reply}, $request->getSummary();

} elsif ( ( $query eq "*" ) or
          ( not $query and
            ( $type eq 'requests' or $type eq 'borrowers' ) ) ) {
    my $requests = Koha::ILLRequests->new()->retrieve_ill_requests();
    foreach my $rq ( @{$requests} ) {
        push @{$reply}, $rq->getSummary();
    }

} elsif ( $type eq 'requests' ) {
    my $requests = Koha::ILLRequests->new()->retrieve_ill_request($query);
    foreach my $rq ( @{$requests} ) {
        push @{$reply}, $rq->getSummary();
    }

} elsif ( $type eq 'borrowers' ) {
    my $requests = Koha::ILLRequests->new()->retrieve_ill_requests($query);
    foreach my $rq ( @{$requests} ) {
        push @{$reply}, $rq->getSummary();
    }

} elsif ( $type eq 'edit' ) {
    my $requests = Koha::ILLRequests->new()->retrieve_ill_request($query);
    foreach my $rq ( @{$requests} ) {
        push @{$reply}, $rq->getForEditing();
    }

} else {
    msg ("no match\n");
}

$template->param( reply => $reply );

output_html_with_http_headers( $input, $cookie, $template->output );
