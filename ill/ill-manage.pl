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
use C4::Members;
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

my $illRequests = Koha::ILLRequests->new;
my $op          = $cgi->param('op');
my $rq          = $cgi->param('rq');
my $request     = 0;
my $here    = "/cgi-bin/koha/ill/ill-manage.pl";
my $tab_url = $here . "?rq=" . $rq . "&op=";
my $parent  = "/cgi-bin/koha/ill/ill-requests.pl";
my $tabs = {};

$request = $illRequests->find($rq) if ($rq);

if ($request) {
    $tabs = build_tabs( {
        op      => $op,
        status  => $request->getStatus,
        manual  => $request->is_manual_request,
        generic => C4::Context->preference('GenericILLModule'),
        mod     => $request->requires_moderation,
    } );
    if ( $op eq 'view' ) {
        $template->param(
            ill   => $request->getFullDetails( { brw => 1 } ),
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

    } elsif ( $op eq 'action_cancel' ) {
        my $result;
        ( $result, $request ) = $request->cancel_request;
        if ( 'cancel_success' eq $result->{status} ) {
            $template->param( title => 'Request reverted' );
        } else {
            $template->param( title => 'Unable to revert request' );
        }
        $op = 'message';
        $template->param(
            message => $result->{status},
            whole   => $result,
            forward => $parent,
        );

    } elsif ( $op eq 'action_email' ) {
        if ( $cgi->param('partner_search') ) {
            # Borrower Search
            my ( $partner_count, $partner ) = validate_partner(
                $cgi->param('partner_search')
            );
            if ( $partner_count == 0 ) {
                $op = 'message';
                $template->param(
                    message => "invalid_partner",
                );
            } else {
                my $forward = $cgi->param('query_type');
                $op = 'select_partner',
                $template->param(
                    forward      => 'action_email',
                    draft        => {
                        subject => $cgi->param('subject'),
                        body    => $cgi->param('body')
                    },
                    select       => $partner,
                    branch       => $cgi->param('branch'),
                );
            }
        } else {
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
        }

    } elsif ( $op eq 'action_request' ) {
        my ( $result, $summary ) = $request->place_request(
            {
                branch  => C4::Context->userenv->{'branch'},
                # FIXME: This is hard-coded to BL values: we need to generate
                # this dynamically from form fields.
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
        if ( 'HASH' eq ref $result and $result->{status} ) {
            $op      = 'message';
            $template->param (
                message => $result->{status},
                whole   => $result,
                forward => $parent,
            );
        } else {
            $template->param( message => 'request_success' );
        }
        $template->param(
            title   => 'API request result',
            forward => $parent,
        );
    } elsif ( $op eq 'action_status' ) {
        my $result;
        ( $result, $request ) = $request->status_request;
        if ( 'status_success' eq $result->{status} ) {
            $template->param( title => 'Current request status details' );
        } else {
            $template->param( title => 'Status could not be retrieved' );
        }
        $op = 'message';
        $template->param(
            message => $result->{status},
            ill     => $request->getSummary,
            whole   => $result,
            forward => $parent,
        )

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
            ill      => $request->getForEditing( { brw => 1 } ),
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
        if ( $ill->{status} ) {
            $op      = 'message';
            $template->param (
                message => $ill->{status},
                whole   => $ill,
                forward => $parent,
            );
        } else {
            $template->param(
                title   => "Availability",
                forward => 'price',
                ill     => $ill,
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
        if ( !GetMember( cardnumber => $cgi->param('borrower') ) ) {
            $op      = 'message';
            $template->param (
                message => 'invalid_borrower',
                whole   => $cgi->param('borrower'),
                forward => $parent,
            );
        } elsif ( !GetBranchDetail($cgi->param('branch')) ) {
            $op      = 'message';
            $template->param (
                message => 'invalid_branch',
                whole   => $cgi->param('branch'),
                forward => $parent,
            );

        } else {
            # We should have a complete set of Request properties / attributes, so we
            # should just be able to push to DB?
            $request->editStatus(\%{$cgi->Vars});
            $template->param(
                ill   => $request->getFullDetails( { brw => 1 } ),
                title => $tabs->{view},
            );
        }

    } else {
        die("Unexpected combination of parameters!")
    }

    $tabs = build_tabs( {
        op      => $op,
        status  => $request->getStatus,
        manual  => $request->is_manual_request,
        generic => C4::Context->preference('GenericILLModule'),
        mod     => $request->requires_moderation,
    } );
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

sub build_tabs {
    my ( $params ) = @_;
    my $tabs = {
        view          => "View",
    };
    if ( 'message' ne $op ) {
        $tabs->{edit} = "Edit";
        if ( $params->{mod} ) {
            $tabs->{moderate} = "Moderation";
        } elsif ( "Requested" eq $params->{status} ) {
            $tabs->{action_cancel} = "Revert request";
            $tabs->{action_status} = "Request status";
        } else {
            unless ( grep { $params->{status} eq $_ } qw/Queued/ ) {
                $tabs->{progress} = "Progress" unless ( $params->{manual} );
                $tabs->{generic_ill} = "Generic ILL"
                    if ( $params->{generic} );
            }
            {$tabs->{action_delete} = "Delete request";}
        }
    }
    return $tabs;
}

sub validate_partner {
    # Perform cardnumber search.  If no results, perform surname search.
    # Return ( 0, undef ), ( 1, $brw ) or ( n, $brws )
    my $input = shift;
    my $borrowers = Koha::Borrowers->new;
    my $ill_code = C4::Context->preference('GenericILLPartners');
    my ( $count, $brw );
    my $brws = $borrowers->search( {
        cardnumber   => $input,
        categorycode => $ill_code,
    } );
    $count = $brws->count;
    if ( $count == 0 ) {
        $brws = $borrowers->search( {
            categorycode => $ill_code,
            surname      => { 'like', '%' . $input . '%' },
        } );
        $count = $brws->count;
        if ( $count == 1 ) {
            $brw = $brws->next;
        } elsif ( $count > 1 ) {
            $brw = $brws;       # found multiple results
        }
    } elsif ( $count == 1 ) {
        $brw = $brws->next;
    } else {
        $brw = $brws;           # found multiple results
    }

    return ( $count, $brw );
}
