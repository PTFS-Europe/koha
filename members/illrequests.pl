#!/usr/bin/perl

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
use Koha::Borrowers;
use C4::Members qw( GetPatronImage );
use C4::Members::Attributes qw(GetBorrowerAttributes);
use Koha::ILL;

my $input = CGI->new();

my $borrowernumber = $input->param('borrowernumber');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'members/illrequests.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => 1,
    }
);

# Get borrower Object
my $borrower = Koha::Borrowers->new()->find($borrowernumber);

# Setup normal template params for members pages - This really should be factored out somewhere!
$template->param( borrower => $borrower );

my ( $picture, $dberror ) = GetPatronImage( $borrower->cardnumber );
if ($picture) {
    $template->param( picture => 1 );
}

if ( C4::Context->preference('ExtendedPatronAttributes') ) {
    my $attributes = GetBorrowerAttributes($borrowernumber);
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes       => $attributes
    );
}

# ILL Requests Tab specifics

# Get ILL configuration, request display is handled via ajax
my $illconfig = Koha::ILL->new()->config;
my @illsummary;

my $properties = $illconfig->record_properties();
foreach my $property ( keys $properties ) {
    if ( defined( $properties->{$property}{'inSummary'} )
        and $properties->{$property}{'inSummary'} eq 'True' )
    {
        push @illsummary, $property;
    }
    else {
        next;
    }
}

$template->param(
    illsummary     => \@illsummary,
    borrowernumber => $borrowernumber,
    ill            => 1,
);
output_html_with_http_headers( $input, $cookie, $template->output );
