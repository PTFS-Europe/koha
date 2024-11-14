#!/usr/bin/perl

# Copyright 2017 PTFS-Europe Ltd
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

use JSON qw( encode_json );

use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Koha;
use C4::Output qw( output_html_with_http_headers );
use POSIX qw( strftime );

use Koha::ILL::Request::Config;
use Koha::ILL::Requests;
use Koha::ILL::Request;
use Koha::ILL::Backends;
use Koha::Libraries;
use Koha::Patrons;
use Koha::ILL::Request::Workflow::Availability;
use Koha::ILL::Request::Workflow::ConfirmAuto;
use Koha::ILL::Request::Workflow::TypeDisclaimer;

my $query = CGI->new;

# Grab all passed data
# 'our' since Plack changes the scoping
# of 'my'
our $params = $query->Vars();

# if illrequests is disabled, leave immediately
if ( ! C4::Context->preference('ILLModule') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
    template_name   => "opac-illrequests.tt",
    query           => $query,
    type            => "opac",
});

# Are we able to actually work?
my $patron = Koha::Patrons->find($loggedinuser);
my $backends = Koha::ILL::Backends->opac_available_backends($patron);
my $backends_available = ( scalar @{$backends} > 0 );
$template->param( backends_available => $backends_available );

my $op = Koha::ILL::Request->get_op_param_deprecation( 'opac', $params );

my ( $illrequest_id, $request );
if ( $illrequest_id = $params->{illrequest_id} ) {
    $request = Koha::ILL::Requests->find($illrequest_id);
    # Make sure the request belongs to the logged in user
    if( !$request || $request->borrowernumber != $loggedinuser ) {
        print $query->redirect("/cgi-bin/koha/errors/404.pl");
        exit;
    }
}

my $can_patron_place_ill_in_opac = Koha::ILL::Request->can_patron_place_ill_in_opac($patron);
if ( ( $op eq 'cud-create' || $op eq 'cancreq' || $op eq 'cud-update' ) && !$can_patron_place_ill_in_opac ) {
    print $query->redirect('/cgi-bin/koha/errors/403.pl');
    exit;
}

if ( $op eq 'list' ) {

    my $requests = Koha::ILL::Requests->search(
        { borrowernumber => $loggedinuser }
    );
    $template->param(
        requests => $requests,
        backends => $backends
    );

} elsif ( $op eq 'view') {
    $template->param(
        request => $request
    );

} elsif ( $op eq 'cud-update') {
    $request->notesopac($params->{notesopac})->store;
    # Send a notice to staff alerting them of the update
    $request->send_staff_notice('ILL_REQUEST_MODIFIED');
    print $query->redirect(
            '/cgi-bin/koha/opac-illrequests.pl?op=view&illrequest_id='
          . $illrequest_id
          . '&message=1' );
    exit;
} elsif ( $op eq 'cancreq') {
    $request->status('CANCREQ')->store;
    print $query->redirect(
            '/cgi-bin/koha/opac-illrequests.pl?op=view&illrequest_id='
          . $illrequest_id
          . '&message=1' );
    exit;
} elsif ( $op eq 'cud-create' ) {
    if (!$params->{backend}) {
        my $req = Koha::ILL::Request->new;
        $template->param(
            backends    => $req->available_backends
        );
    } else {
        $params->{backend} = 'Standard' if $params->{backend} eq 'FreeForm';
        my $request = Koha::ILL::Request->new
            ->load_backend($params->{backend});

        # Before request creation operations - Preparation
        my $availability =
          Koha::ILL::Request::Workflow::Availability->new( $params, 'opac' );
        my $type_disclaimer =
          Koha::ILL::Request::Workflow::TypeDisclaimer->new( $params, 'opac' );
        my $confirm_auto =
          Koha::ILL::Request::Workflow::ConfirmAuto->new( $params, 'opac' );

        # ILLCheckAvailability operation
        if ($availability->show_availability($request)) {
            $op = 'availability';
            $template->param(
                $availability->availability_template_params($params)
            );
            output_html_with_http_headers $query, $cookie,
                $template->output, undef,
                { force_no_caching => 1 };
            exit;
        # ILLModuleDisclaimerByType operation
        } elsif ( $type_disclaimer->show_type_disclaimer($request)) {
            $op = 'typedisclaimer';
            $template->param(
                $type_disclaimer->type_disclaimer_template_params($params)
            );
            output_html_with_http_headers $query, $cookie,
                $template->output, undef,
                { force_no_caching => 1 };
            exit;
        # ConfirmAuto operation
        } elsif ( $confirm_auto->show_confirm_auto($request)) {
            $op = 'confirmautoill';
            $template->param(
                $confirm_auto->confirm_auto_template_params($params)
            );
            output_html_with_http_headers $query, $cookie,
                $template->output, undef,
                { force_no_caching => 1 };
            exit;
        }

        my $patron = Koha::Patrons->find( { borrowernumber => $loggedinuser } );

        $params->{cardnumber} = $patron->cardnumber;
        $params->{branchcode} = $patron->branchcode;
        $params->{opac}       = 1;
        $params->{lang}       = C4::Languages::getlanguage($query);
        my $backend_result = $request->backend_create($params);

        if ($backend_result->{stage} eq 'copyrightclearance') {
            $template->param(
                stage       => $backend_result->{stage},
                whole       => $backend_result
            );
        } else {
            $template->param(
                types       => [ "Book", "Article", "Journal" ],
                branches    => Koha::Libraries->search->unblessed,
                whole       => $backend_result,
                request     => $request
            );
            if ($backend_result->{stage} eq 'commit') {
                # After creation actions
                if ( $params->{type_disclaimer_submitted} ) {
                    $type_disclaimer->after_request_created( $params, $request );
                }
                print $query->redirect('/cgi-bin/koha/opac-illrequests.pl?message=2');
                exit;
            }
        }

    }
}

$template->param(
    unauthenticated_ill          => C4::Context->preference('ILLOpacUnauthenticatedRequest'),
    can_patron_place_ill_in_opac => $can_patron_place_ill_in_opac,
    message                      => $params->{message},
    illrequestsview              => 1,
    op                           => $op
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
