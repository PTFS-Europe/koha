#!/usr/bin/perl

# Copyright 2008 LibLime
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

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use C4::Members::Messaging;
use C4::Form::MessagingPreferences;
use Koha::Patrons;
use Koha::SMS::Providers;
use Koha::Token;

my $query = CGI->new();

unless ( C4::Context->preference('EnhancedMessagingPreferencesOPAC') and
         C4::Context->preference('EnhancedMessagingPreferences') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-messaging.tt',
        query           => $query,
        type            => 'opac',
    }
);

my $patron = Koha::Patrons->find( $borrowernumber ); # FIXME and if borrowernumber is invalid?

my $messaging_options = C4::Members::Messaging::GetMessagingOptions();

if ( defined $query->param('modify') && $query->param('modify') eq 'yes' ) {
    die "Wrong CSRF token" unless Koha::Token->new->check_csrf({
        session_id => scalar $query->cookie('CGISESSID'),
        token  => scalar $query->param('csrf_token'),
    });

    my $sms = $query->param('SMSnumber');
    my $sms_provider_id = $query->param('sms_provider_id');
    $patron->set({
        smsalertnumber  => $sms,
        sms_provider_id => $sms_provider_id,
    })->store;

    C4::Form::MessagingPreferences::handle_form_action($query, { borrowernumber => $patron->borrowernumber }, $template);

    if ( C4::Context->preference('TranslateNotices') ) {
        $patron->set({ lang => scalar $query->param('lang') })->store;
    }
}

C4::Form::MessagingPreferences::set_form_values({ borrowernumber     => $patron->borrowernumber }, $template);

$template->param(
                  messagingview         => 1,
                  SMSnumber             => $patron->smsalertnumber, # FIXME This is already sent 2 lines above
                  SMSSendDriver                =>  C4::Context->preference("SMSSendDriver"),
                  TalkingTechItivaPhone        =>  C4::Context->preference("TalkingTechItivaPhoneNotification") );

if ( C4::Context->preference("SMSSendDriver") eq 'Email' ) {
    my @providers = Koha::SMS::Providers->search( {}, { order_by => 'name' } )->as_list;
    $template->param(
            sms_providers => \@providers,
            sms_provider_id => $patron->sms_provider_id );
}

my $new_session_id = $query->cookie('CGISESSID');
$template->param(
    csrf_token => Koha::Token->new->generate_csrf({
            session_id => $new_session_id,
        }),
);

if ( C4::Context->preference('TranslateNotices') ) {
    my $translated_languages = C4::Languages::getTranslatedLanguages( 'opac', C4::Context->preference('template') );
    $template->param(
        languages => $translated_languages,
        patron_lang => $patron->lang,
    );
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
