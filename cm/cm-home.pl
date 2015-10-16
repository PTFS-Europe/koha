#!/usr/bin/perl
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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA
#

use Modern::Perl;
use CGI;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Context;
use Koha::Till;
use C4::Members qw( GetMember );
use C4::Branch qw( GetBranchName GetBranch );

my $query     = CGI->new();
my $sessionID = $query->cookie('CGISESSID');
my $session   = get_session($sessionID);

my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/cm-home.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $branch = $query->param('branch') || $session->param('branch');

my $user       = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname = GetBranchName($branch);
my $tillid     = $query->param('tillid');
if ( !$tillid ) {
    $tillid = $session->param('tillid')
      || Koha::Till->branch_tillid($branch);
}

# here be tigers
#

$template->param( branchname => $branchname, tillid => $tillid );

output_html_with_http_headers( $query, $cookie, $template->output );
