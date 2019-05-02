#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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
use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Context;
use C4::Koha;
use C4::Letters;
use C4::Serials;


my $query = new CGI;
my $op    = $query->param('op') || '';
my $dbh   = C4::Context->dbh;

my $sth;
my ( $template, $loggedinuser, $cookie );
my $subscriptionid = $query->param('subscriptionid');
my $referer      = $query->param('referer') || 'detail';
my $biblionumber = $query->param('biblionumber');

( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-alert-subscribe.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0, # user must logged in to request
                              # subscription notifications
        debug           => 1,
    }
);

my $subscription = Koha::Subscriptions->find( $subscriptionid );
my $logged_in_patron = Koha::Patrons->find( $loggedinuser );

if ( $op eq 'alert_confirmed' ) {
    $subscription->add_subscriber( $logged_in_patron );
    if ( $referer eq 'serial' ) {
        print $query->redirect(
            "opac-serial-issues.pl?biblionumber=$biblionumber");
        exit;
    } else {
        print $query->redirect(
            "opac-detail.pl?biblionumber=$biblionumber");
        exit;
    }
}
elsif ( $op eq 'cancel_confirmed' ) {
    $subscription->remove_subscriber( $logged_in_patron );
    warn "CANCEL confirmed : $loggedinuser, $subscriptionid";
    if ( $referer eq 'serial' ) {
        print $query->redirect(
            "opac-serial-issues.pl?biblionumber=$biblionumber");
        exit;
    } else {
        print $query->redirect(
            "opac-detail.pl?biblionumber=$biblionumber");
        exit;
    }


}
else {
    my $subscription = &GetSubscription($subscriptionid);
    $template->param(
        referer        => $referer,
        "typeissue$op" => 1,
        bibliotitle    => $subscription->{bibliotitle},
        notes          => $subscription->{notes},
        subscriptionid     => $subscriptionid,
        biblionumber   => $biblionumber,
    );
}
output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
