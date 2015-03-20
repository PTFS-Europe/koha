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
use C4::Branch;
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
        flagsrequired => { ill => 'manage' },
    }
);

my $op      = $cgi->param('op');
my $rq      = $cgi->param('rq');
my $request = 0;
if ($rq) {
    $request = @{Koha::ILLRequests->new->retrieve_ill_request($rq) || [0]}[0];
}
my $here    = "/cgi-bin/koha/ill/ill-manage.pl";
my $tab_url = $here . "?rq=" . $rq . "&op=";
my $parent  = "/cgi-bin/koha/ill/ill-requests.pl";

my $tabs = {
    view          => "View",
    edit          => "Edit",
    progress      => "Progress",
    action_delete => "Delete",
};

if (C4::Context->preference('GenericILLModule')) {
    $tabs->{generic_ill} = "Generic ILL";
}

if ($request) {
    if ($request and $request->requires_moderation) {
        $tabs->{moderate} = "Moderation";
    }

    if ( $op eq 'view' ) {
        $template->param(
            ill   => $request->getSummary,
            title => $tabs->{$op},
        );

    } elsif ( $op eq 'action_delete' ) {
        if ( $request->delete ) {
            $op = 'message';
            $template->param(
                message => 'deleted',
                title   => 'Deleted',
                forward => $parent,
            );
        } else {
            $template->param(
                message => 'failure',
                title   => 'Not deleted',
                forward => $parent,
            );
        }

    } elsif ( $op eq 'action_email' ) {
        my $branchdetails = GetBranchDetail(C4::Context->userenv->{'branch'});
        my ( $result, $summary ) = $request->place_generic_request(
            {
                to          => [ $cgi->param('partners') ],
                from        => $branchdetails->{'branchemail'},
                replyto     => $branchdetails->{'branchreplyto'},
                sender      => $branchdetails->{'branchreturnpath'},
                subject     => Encode::encode( "utf8", $cgi->param('subject') ),
                message     => Encode::encode( "utf8", $cgi->param('body') ),
                contenttype => 'text/plain; charset="utf8"',
            }
        );
        $op = 'message';
        ( $result ) ? $template->param( message => 'email_success' )
            : $template->param( message => 'email_failure' );
        $template->param(
            title   => 'Email request result',
            email   => $summary,
            forward => $parent,
        );

    } elsif ( $op eq 'action_request' ) {
        my ( $result, $summary ) = $request->place_request(
            {
                branch  => C4::Context->userenv->{'branch'},
                # This is hard-coded to BL values: we need to generate this
                # dynamically from form fields.
                details => {
                    format   => $cgi->param('format'),
                    speed    => $cgi->param('speed'),
                    quality  => $cgi->param('quality'),
                    service  => $cgi->param('service'),
                    quantity => 1, # hard-coded to 1 for now
                }
            }
        );
        $op = 'message';
        ( $result ) ? $template->param( message => 'request_success' )
            : $template->param( message => 'request_failure' );
        $template->param(
            title   => 'API request result',
            forward => $parent,
        );

    } elsif ( $op eq 'generic_ill') {
        my $ill_code = C4::Context->preference('GenericILLPartners');
        my @partners = Koha::Borrowers->new->search( { categorycode => $ill_code } );
        $template->param(
            draft    => $request->prepare_generic_request,
            partners => \@partners,
            title    => $tabs->{$op},
            forward  => "action_email",
            back     => $tab_url . "view",
        );

    } elsif ( $op eq 'edit' ) {
        $template->param(
            branches => GetBranchesLoop,
            ill      => $request->getForEditing,
            title    => $tabs->{$op},
            forward  => "update",
        );

    } elsif ( $op eq 'moderate' ) {
        my $moderation = $request->requires_moderation;
        my $forward = 'view';
        my $back    = $tab_url . "view";
        my $title   = "View";
        if ($moderation eq "Cancellation Requested") {
            $forward = 'action_delete';
            $title   = "Deletion requested";
        }
        $template->param(
            title   => $title,
            back    => $back,
            forward => $forward,
        )

    } elsif ( $op eq 'progress' ) {
        my $ill = $request->checkSimpleAvailability;
        if ($ill) {
            $template->param(
                title   => "Availability",
                forward => 'price',
                ill     => $ill,
            );
        } else {
            $op      = 'message';
            $template->param (
                message => 'api',
                forward => $parent,
            );
        }

    } elsif ( $op eq 'price' ) {
        my $coordinates = {
            format  => $cgi->param('format'),
            speed   => $cgi->param('speed'),
            quality => $cgi->param('quality'),
        };
        $template->param(
            ill         => $request->calculatePrice($coordinates),
            title       => "Prices",
            forward     => "action_request",
            coordinates => $coordinates,
        );

    } elsif ( $op eq 'update' ) {
        # We should have a complete set of Request properties / attributes, so we
        # should just be able to push to DB?
        $request->editStatus(\%{$cgi->Vars});
        $template->param(
            ill   => $request->getSummary,
            title => $tabs->{view},
        );

    } else {
        die("Unexpected combination of parameters!")
    }
} else {
    $op      = 'message';
    $template->param (
        message => 'unknown_request',
        forward => $parent,
    );
}

$template->param(
    here    => $here,
    op      => $op,
    rq      => $rq,
    tab_url => $tab_url,
    tabs    => $tabs,
);

output_html_with_http_headers( $cgi, $cookie, $template->output );
