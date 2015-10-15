#!/usr/bin/perl

# Copyright 2015 PTFS-Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
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

use C4::Context;
use C4::Output;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Koha;
use Koha::Till;

my $query = CGI->new();

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'cm/selecttill.tt',
        query           => $query,
        type            => 'intranet',
        debug           => 1,
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1, },
    }
);

my $sessionID = $query->cookie('CGISESSID');
my $session   = get_session($sessionID);
my $curr_till = $session->param('tillid') || -1;
my $updated   = 0;

#my $old_tillid = $session->param('tillid') || -1;
my $old_tillid = $curr_till;
my $tillid     = $query->param('till');

if ($tillid) {

    #    C4::Context->set_tillid($tillid);
    $template->param( tillid => $tillid );
    $session->param( 'tillid', $tillid );
    $curr_till = $tillid;
    $updated   = $tillid != $old_tillid;
}

#else {
# fallback to userenv
#    $tillid = C4::Context->userenv->{tillid};
#}

my $recycle_loop = [];    #???
@{$recycle_loop} = map {
    { param => $_, value => $query->param($_) }
    if ( $_ && $_ !~ m/^(tillid|oldreferer)$/ )
} $query->param();

my $branch = C4::Context->userenv->{branch};
my $referer = $query->param('oldreferer') || $ENV{HTTP_REFERER};
if ( $referer =~ /selecttill\.pl/ ) {
    undef $referer;       # avoid sending them back to this same page.
}

if ($updated) {
    $template->param( updated => $updated );
    if ( !@{$recycle_loop} ) {
        print $query->redirect( $referer
              || '/cgi-bin/koha/circ/circulation.pl' );
    }
}

my $till_list = Koha::Till->get_till_list($branch);

$template->param(
    referer      => $referer,
    till_list    => $till_list,
    current_till => $curr_till,
    recycle_loop => $recycle_loop,
);

output_html_with_http_headers( $query, $cookie, $template->output );
