package C4::Auth;

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

use strict;
use warnings;
use Carp qw( croak );

use Digest::MD5 qw( md5_base64 );
use CGI::Session;
use CGI::Session::ErrorHandler;
use URI;
use URI::QueryParam;
use List::MoreUtils qw( uniq );

use C4::Context;
use C4::Templates;    # to get the template
use C4::Languages;
use C4::Search::History;
use C4::Output qw( output_and_exit );
use Koha;
use Koha::Logger;
use Koha::Caches;
use Koha::AuthUtils qw( get_script_name hash_password );
use Koha::Auth::TwoFactorAuth;
use Koha::Checkouts;
use Koha::DateUtils qw( dt_from_string );
use Koha::Library::Groups;
use Koha::Libraries;
use Koha::Cash::Registers;
use Koha::Desks;
use Koha::Patrons;
use Koha::Patron::Consents;
use List::MoreUtils qw( any );
use Encode;
use C4::Auth_with_shibboleth qw( shib_ok get_login_shib login_shib_url logout_shib checkpw_shib );
use Net::CIDR;
use C4::Log qw( logaction );
use Koha::CookieManager;
use Koha::Auth::Permissions;
use Koha::Token;
use Koha::Exceptions::Token;
use Koha::Session;

# use utf8;

use vars qw($ldap $cas $caslogout);
our ( @ISA, @EXPORT_OK );

#NOTE: The utility of keeping the safe_exit function is that it can be easily re-defined in unit tests and plugins
sub safe_exit {

    # It's fine for us to "exit" because CGI::Compile (used in Plack::App::WrapCGI) redefines "exit" for us automatically.
    # Since we only seem to use C4::Auth::safe_exit in a CGI context, we don't actually need PSGI detection at all here.
    exit;
}

BEGIN {
    C4::Context->set_remote_address;

    require Exporter;
    @ISA = qw(Exporter);

    @EXPORT_OK = qw(
        checkauth check_api_auth get_session check_cookie_auth checkpw checkpw_internal checkpw_hash
        get_all_subpermissions get_cataloguing_page_permissions get_user_subpermissions in_iprange
        get_template_and_user haspermission create_basic_session
    );

    $cas       = C4::Context->preference('casAuthentication');
    $caslogout = C4::Context->preference('casLogout');

    if ($cas) {
        require C4::Auth_with_cas;    # no import
        import C4::Auth_with_cas
            qw(check_api_auth_cas checkpw_cas login_cas logout_cas login_cas_url logout_if_required multipleAuth getMultipleAuth);
    }

}

=head1 NAME

C4::Auth - Authenticates Koha users

=head1 SYNOPSIS

  use CGI qw ( -utf8 );
  use C4::Auth;
  use C4::Output;

  my $query = CGI->new;

  my ($template, $borrowernumber, $cookie)
    = get_template_and_user(
        {
            template_name   => "opac-main.tt",
            query           => $query,
      type            => "opac",
      authnotrequired => 0,
      flagsrequired   => { catalogue => '*', tools => 'import_patrons' },
  }
    );

  output_html_with_http_headers $query, $cookie, $template->output;

=head1 DESCRIPTION

The main function of this module is to provide
authentification. However the get_template_and_user function has
been provided so that a users login information is passed along
automatically. This gets loaded into the template.

=head1 FUNCTIONS

=head2 get_template_and_user

 my ($template, $borrowernumber, $cookie)
     = get_template_and_user(
       {
         template_name   => "opac-main.tt",
         query           => $query,
         type            => "opac",
         authnotrequired => 0,
         flagsrequired   => { catalogue => '*', tools => 'import_patrons' },
       }
     );

This call passes the C<query>, C<flagsrequired> and C<authnotrequired>
to C<&checkauth> (in this module) to perform authentification.
See C<&checkauth> for an explanation of these parameters.

The C<template_name> is then used to find the correct template for
the page. The authenticated users details are loaded onto the
template in the logged_in_user variable (which is a Koha::Patron object). Also the
C<sessionID> is passed to the template. This can be used in templates
if cookies are disabled. It needs to be put as and input to every
authenticated page.

More information on the C<gettemplate> sub can be found in the
Output.pm module.

=cut

sub get_template_and_user {

    my $in = shift;
    my ( $user, $cookie, $sessionID, $flags );
    $cookie = [];

    my $cookie_mgr = Koha::CookieManager->new;

    # Get shibboleth login attribute
    my $shib       = C4::Context->preference('ShibbolethAuthentication') && shib_ok();
    my $shib_login = $shib ? get_login_shib() : undef;

    C4::Context->interface( $in->{type} );

    $in->{'authnotrequired'} ||= 0;

    # the following call includes a bad template check; might croak
    my $template = C4::Templates::gettemplate(
        $in->{'template_name'},
        $in->{'type'},
        $in->{'query'},
    );

    if ( C4::Context->preference('AutoSelfCheckAllowed') && $in->{template_name} =~ m|sco/| ) {
        my $AutoSelfCheckID   = C4::Context->preference('AutoSelfCheckID');
        my $AutoSelfCheckPass = C4::Context->preference('AutoSelfCheckPass');
        $in->{query}->param( -name => 'login_userid',       -values => [$AutoSelfCheckID] );
        $in->{query}->param( -name => 'login_password',     -values => [$AutoSelfCheckPass] );
        $in->{query}->param( -name => 'koha_login_context', -values => ['sco'] );
    } else {
        my $request_method = $in->{query}->request_method // q{};
        unless ( $request_method eq 'POST' && $in->{query}->param('op') eq 'cud-login' ) {
            for my $v (qw( login_userid login_password )) {
                $in->{query}->param( $v, '' )
                    if $in->{query}->param($v);
            }
        }
    }

    if ( $in->{'template_name'} !~ m/maintenance/ ) {
        ( $user, $cookie, $sessionID, $flags ) = checkauth(
            $in->{'query'},
            $in->{'authnotrequired'},
            $in->{'flagsrequired'},
            $in->{'type'},
            undef,
            $in->{template_name},
            { skip_csrf_check => 1 },
        );
    }

    my $session = get_session($sessionID);

    # If we enforce GDPR and the user did not consent, redirect
    # Exceptions for consent page itself and SCI/SCO system
    if (   $in->{type} eq 'opac'
        && $user
        && $in->{'template_name'} !~ /^(opac-page|opac-patron-consent|sc[io]\/)/
        && C4::Context->preference('PrivacyPolicyConsent') eq 'Enforced' )
    {
        my $consent = Koha::Patron::Consents->search(
            {
                borrowernumber => getborrowernumber($user),
                type           => 'GDPR_PROCESSING',
                given_on       => { '!=', undef },
            }
        )->next;
        if ( !$consent ) {
            print $in->{query}->redirect( -uri => '/cgi-bin/koha/opac-patron-consent.pl', -cookie => $cookie );
            safe_exit;
        }
    }

    if ( $in->{type} eq 'opac' && $user ) {
        my $is_sco_user;
        if ($session) {
            $is_sco_user = $session->param('sco_user');
        }
        my $kick_out;

        if (
            # If the user logged in is the SCO user and they try to go out of the SCO module,
            # log the user out removing the CGISESSID cookie
            $in->{template_name} !~ m|sco/|
            && $in->{template_name} !~ m|errors/errorpage.tt|
            && (
                $is_sco_user
                || ( C4::Context->preference('AutoSelfCheckID')
                    && $user eq C4::Context->preference('AutoSelfCheckID') )
            )
            )
        {
            $kick_out = 1;
        } elsif (

            # If the user logged in is the SCI user and they try to go out of the SCI module,
            # kick them out unless it is SCO with a valid permission
            # or they are a superlibrarian
               $in->{template_name} !~ m|sci/|
            && $in->{template_name} !~ m|errors/errorpage.tt|
            && haspermission( $user, { self_check => 'self_checkin_module' } )
            && !( $in->{template_name} =~ m|sco/| && haspermission( $user, { self_check => 'self_checkout_module' } ) )
            && $flags
            && $flags->{superlibrarian} != 1
            )
        {
            $kick_out = 1;
        }

        if ($kick_out) {
            $template = C4::Templates::gettemplate(
                'opac-auth.tt', 'opac',
                $in->{query}
            );
            $cookie = $cookie_mgr->replace_in_list(
                $cookie,
                $in->{query}->cookie(
                    -name     => 'CGISESSID',
                    -value    => '',
                    -HttpOnly => 1,
                    -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                    -sameSite => 'Lax',
                )
            );

            #NOTE: This JWT should only be used by the self-check controllers
            $cookie = $cookie_mgr->replace_in_list(
                $cookie,
                $in->{query}->cookie(
                    -name     => 'JWT',
                    -value    => '',
                    -HttpOnly => 1,
                    -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                    -sameSite => 'Lax',
                )
            );

            my $auth_error = $in->{query}->param('auth_error');

            $template->param(
                loginprompt => 1,
                script_name => get_script_name(),
                auth_error  => $auth_error,
            );

            print $in->{query}->header(
                {
                    type              => 'text/html',
                    charset           => 'utf-8',
                    cookie            => $cookie,
                    'X-Frame-Options' => 'SAMEORIGIN'
                }
                ),
                $template->output;
            safe_exit;
        }
    }

    my $borrowernumber;
    my $patron;
    if ($user) {

        # It's possible for $user to be the borrowernumber if they don't have a
        # userid defined (and are logging in through some other method, such
        # as SSL certs against an email address)
        $borrowernumber = getborrowernumber($user) if defined($user);
        if ( !defined($borrowernumber) && defined($user) ) {
            $patron = Koha::Patrons->find($user);
            if ($patron) {
                $borrowernumber = $user;

                # A bit of a hack, but I don't know there's a nicer way
                # to do it.
                $user = $patron->firstname . ' ' . $patron->surname;
            }
        } else {
            $patron = Koha::Patrons->find($borrowernumber);

            # FIXME What to do if $patron does not exist?
        }

        if ( $in->{'type'} eq 'opac' ) {
            require Koha::Virtualshelves;
            my $some_private_shelves = Koha::Virtualshelves->get_some_shelves(
                {
                    borrowernumber => $borrowernumber,
                    public         => 0,
                }
            );
            my $some_public_shelves = Koha::Virtualshelves->get_some_shelves(
                {
                    public => 1,
                }
            );
            $template->param(
                some_private_shelves => $some_private_shelves,
                some_public_shelves  => $some_public_shelves,
            );
        }

        # We are going to use the $flags returned by checkauth
        # to create the template's parameters that will indicate
        # which menus the user can access.
        my $authz = Koha::Auth::Permissions->get_authz_from_flags( { flags => $flags } );
        foreach my $permission ( keys %{$authz} ) {
            $template->param( $permission => $authz->{$permission} );
        }

        # Logged-in opac search history
        # If the requested template is an opac one and opac search history is enabled
        if ( $in->{type} eq 'opac' && C4::Context->preference('EnableOpacSearchHistory') ) {
            my $dbh   = C4::Context->dbh;
            my $query = "SELECT COUNT(*) FROM search_history WHERE userid=?";
            my $sth   = $dbh->prepare($query);
            $sth->execute($borrowernumber);

            # If at least one search has already been performed
            if ( $sth->fetchrow_array > 0 ) {

                # We show the link in opac
                $template->param( EnableOpacSearchHistory => 1 );
            }
            if ( C4::Context->preference('LoadSearchHistoryToTheFirstLoggedUser') ) {

                # And if there are searches performed when the user was not logged in,
                # we add them to the logged-in search history
                my @recentSearches = C4::Search::History::get_from_session( { cgi => $in->{'query'} } );
                if (@recentSearches) {
                    my $query = q{
                        INSERT INTO search_history(userid, sessionid, query_desc, query_cgi, type,  total, time )
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    };
                    my $sth = $dbh->prepare($query);
                    $sth->execute(
                        $borrowernumber,
                        $in->{query}->cookie("CGISESSID"),
                        $_->{query_desc},
                        $_->{query_cgi},
                        $_->{type} || 'biblio',
                        $_->{total},
                        $_->{time},
                    ) foreach @recentSearches;

                    # clear out the search history from the session now that
                    # we've saved it to the database
                }
            }
            C4::Search::History::set_to_session( { cgi => $in->{'query'}, search_history => [] } );

        } elsif ( $in->{type} eq 'intranet' and C4::Context->preference('EnableSearchHistory') ) {
            $template->param( EnableSearchHistory => 1 );
        }
    } else {    # if this is an anonymous session, setup to display public lists...

        # If shibboleth is enabled, and we're in an anonymous session, we should allow
        # the user to attempt login via shibboleth.
        if ($shib) {
            $template->param(
                shibbolethAuthentication => $shib,
                shibbolethLoginUrl       => login_shib_url( $in->{'query'} ),
            );

            # If shibboleth is enabled and we have a shibboleth login attribute,
            # but we are in an anonymous session, then we clearly have an invalid
            # shibboleth koha account.
            if ($shib_login) {
                $template->param( invalidShibLogin => '1' );
            }
        }

        if ( $in->{'type'} eq 'opac' ) {
            require Koha::Virtualshelves;
            my $some_public_shelves = Koha::Virtualshelves->get_some_shelves(
                {
                    public => 1,
                }
            );
            $template->param(
                some_public_shelves => $some_public_shelves,
            );

            # Set default branch if one has been passed by the environment.
            $template->param( default_branch => $ENV{OPAC_BRANCH_DEFAULT} ) if $ENV{OPAC_BRANCH_DEFAULT};
        }
    }

    # Sysprefs disabled via URL param
    # Note that value must be defined in order to override via ENV
    foreach my $syspref (
        qw(
        OPACUserCSS
        OPACUserJS
        IntranetUserCSS
        IntranetUserJS
        OpacAdditionalStylesheet
        opaclayoutstylesheet
        intranetcolorstylesheet
        intranetstylesheet
        )
        )
    {
        $ENV{"OVERRIDE_SYSPREF_$syspref"} = q{}
            if $in->{'query'}->param("DISABLE_SYSPREF_$syspref");
    }

    # Anonymous opac search history
    # If opac search history is enabled and at least one search has already been performed
    if ( C4::Context->preference('EnableOpacSearchHistory') ) {
        my @recentSearches = C4::Search::History::get_from_session( { cgi => $in->{'query'} } );
        if (@recentSearches) {
            $template->param( EnableOpacSearchHistory => 1 );
        }
    }

    if ( C4::Context->preference('dateformat') ) {
        $template->param( dateformat => C4::Context->preference('dateformat') );
    }

    $template->param( auth_forwarded_hash => scalar $in->{'query'}->param('auth_forwarded_hash') );

    # these template parameters are set the same regardless of $in->{'type'}

    my $minPasswordLength = C4::Context->preference('minPasswordLength');
    $minPasswordLength = 3 if not $minPasswordLength or $minPasswordLength < 3;
    $template->param(
        EnhancedMessagingPreferences => C4::Context->preference('EnhancedMessagingPreferences'),
        GoogleJackets                => C4::Context->preference("GoogleJackets"),
        OpenLibraryCovers            => C4::Context->preference("OpenLibraryCovers"),
        KohaAdminEmailAddress        => "" . C4::Context->preference("KohaAdminEmailAddress"),
        LoginFirstname               => ( C4::Context->userenv ? C4::Context->userenv->{"firstname"} : "Bel" ),
        LoginSurname                 => C4::Context->userenv ? C4::Context->userenv->{"surname"}      : "Inconnu",
        emailaddress                 => C4::Context->userenv ? C4::Context->userenv->{"emailaddress"} : undef,
        TagsEnabled                  => C4::Context->preference("TagsEnabled"),
        hide_marc                    => C4::Context->preference("hide_marc"),
        item_level_itypes            => C4::Context->preference('item-level_itypes'),
        patronimages                 => C4::Context->preference("patronimages"),
        singleBranchMode             => ( Koha::Libraries->search->count == 1 ),
        noItemTypeImages             => C4::Context->preference("noItemTypeImages"),
        marcflavour                  => C4::Context->preference("marcflavour"),
        OPACBaseURL                  => C4::Context->preference('OPACBaseURL'),
        minPasswordLength            => $minPasswordLength,
    );
    if ( $in->{'type'} eq "intranet" ) {

        $template->param(
            advancedMARCEditor            => C4::Context->preference("advancedMARCEditor"),
            AllowMultipleCovers           => C4::Context->preference('AllowMultipleCovers'),
            AmazonCoverImages             => C4::Context->preference("AmazonCoverImages"),
            StaffLoginRestrictLibraryByIP => C4::Context->preference("StaffLoginRestrictLibraryByIP"),
            can_see_cataloguing_module    => haspermission( $user, get_cataloguing_page_permissions() ) ? 1 : 0,
            canreservefromotherbranches   => C4::Context->preference('canreservefromotherbranches'),
            EasyAnalyticalRecords         => C4::Context->preference('EasyAnalyticalRecords'),
            EnableBorrowerFiles           => C4::Context->preference('EnableBorrowerFiles'),
            FRBRizeEditions               => C4::Context->preference("FRBRizeEditions"),
            IndependentBranches           => C4::Context->preference("IndependentBranches"),
            intranetcolorstylesheet       => C4::Context->preference("intranetcolorstylesheet"),
            IntranetFavicon               => C4::Context->preference("IntranetFavicon"),
            IntranetmainUserblock         => C4::Context->preference("IntranetmainUserblock"),
            IntranetNav                   => C4::Context->preference("IntranetNav"),
            intranetreadinghistory        => C4::Context->preference("intranetreadinghistory"),
            IntranetReadingHistoryHolds   => C4::Context->preference("IntranetReadingHistoryHolds"),
            intranetstylesheet            => C4::Context->preference("intranetstylesheet"),
            IntranetUserCSS               => C4::Context->preference("IntranetUserCSS"),
            IntranetUserJS                => C4::Context->preference("IntranetUserJS"),
            LibraryName                   => C4::Context->preference("LibraryName"),
            LocalCoverImages              => C4::Context->preference('LocalCoverImages'),
            OPACLocalCoverImages          => C4::Context->preference('OPACLocalCoverImages'),
            PatronAutoComplete            => C4::Context->preference("PatronAutoComplete"),
            pending_checkout_notes        => Koha::Checkouts->search( { noteseen => 0 } ),
            plugins_enabled               => C4::Context->config("enable_plugins"),
            StaffSerialIssueDisplayCount  => C4::Context->preference("StaffSerialIssueDisplayCount"),
            UseCourseReserves             => C4::Context->preference("UseCourseReserves"),
            useDischarge                  => C4::Context->preference('useDischarge'),
            virtualshelves                => C4::Context->preference("virtualshelves"),
        );
    } else {
        warn "template type should be OPAC, here it is=[" . $in->{'type'} . "]" unless ( $in->{'type'} eq 'opac' );

        #TODO : replace LibraryName syspref with 'system name', and remove this html processing
        my $LibraryNameTitle = C4::Context->preference("LibraryName");
        $LibraryNameTitle =~ s/<(?:\/?)(?:br|p)\s*(?:\/?)>/ /sgi;
        $LibraryNameTitle =~ s/<(?:[^<>'"]|'(?:[^']*)'|"(?:[^"]*)")*>//sg;

        # clean up the busc param in the session
        # if the page is not opac-detail and not the "add to list" page
        # and not the "edit comments" page
        if ( C4::Context->preference("OpacBrowseResults")
            && $in->{'template_name'} =~ /opac-(.+)\.(?:tt|tmpl)$/ )
        {
            my $pagename = $1;
            unless ( $pagename =~ /^(?:MARC|ISBD)?detail$/
                or $pagename =~ /^showmarc$/
                or $pagename =~ /^addbybiblionumber$/
                or $pagename =~ /^review$/ )
            {
                $session->clear( ["busc"] ) if $session;
            }
        }

        # variables passed from CGI: opac_css_override and opac_search_limits.
        my $opac_search_limit   = $ENV{'OPAC_SEARCH_LIMIT'};
        my $opac_limit_override = $ENV{'OPAC_LIMIT_OVERRIDE'};
        my $opac_name           = '';
        if (   ( $opac_limit_override && $opac_search_limit && $opac_search_limit =~ /^branch:([\w-]+)/ )
            || ( $in->{'query'}->param('limit') && $in->{'query'}->param('limit') =~ /^branch:([\w-]+)/ )
            || ( $in->{'query'}->param('limit') && $in->{'query'}->param('limit') =~ /^multibranchlimit:(\w+)/ ) )
        {
            $opac_name = $1;    # opac_search_limit is a branch, so we use it.
        } elsif ( $in->{'query'}->param('multibranchlimit') ) {
            $opac_name = $in->{'query'}->param('multibranchlimit');
        } elsif ( C4::Context->preference("SearchMyLibraryFirst")
            && C4::Context->userenv
            && C4::Context->userenv->{'branch'} )
        {
            $opac_name = C4::Context->userenv->{'branch'};
        }

        # Decide if the patron can make suggestions in the OPAC
        my $can_make_suggestions;
        if ( C4::Context->preference('Suggestion') && C4::Context->preference('AnonSuggestions') ) {
            $can_make_suggestions = 1;
        } elsif ( C4::Context->userenv && C4::Context->userenv->{'number'} ) {
            $can_make_suggestions =
                Koha::Patrons->find( C4::Context->userenv->{'number'} )->category->can_make_suggestions;
        }

        my @search_groups = Koha::Library::Groups->get_search_groups( { interface => 'opac' } )->as_list;
        $template->param(
            AnonSuggestions        => "" . C4::Context->preference("AnonSuggestions"),
            LibrarySearchGroups    => \@search_groups,
            opac_name              => $opac_name,
            LibraryName            => "" . C4::Context->preference("LibraryName"),
            LibraryNameTitle       => "" . $LibraryNameTitle,
            OPACAmazonCoverImages  => C4::Context->preference("OPACAmazonCoverImages"),
            OPACFRBRizeEditions    => C4::Context->preference("OPACFRBRizeEditions"),
            OpacHighlightedWords   => C4::Context->preference("OpacHighlightedWords"),
            OPACShelfBrowser       => "" . C4::Context->preference("OPACShelfBrowser"),
            OPACURLOpenInNewWindow => "" . C4::Context->preference("OPACURLOpenInNewWindow"),
            OpacAuthorities        => C4::Context->preference("OpacAuthorities"),
            opac_css_override      => $ENV{'OPAC_CSS_OVERRIDE'},
            opac_search_limit      => $opac_search_limit,
            opac_limit_override    => $opac_limit_override,
            OpacBrowser            => C4::Context->preference("OpacBrowser"),
            OpacCloud              => C4::Context->preference("OpacCloud"),
            OpacKohaUrl            => C4::Context->preference("OpacKohaUrl"),
            OpacPasswordChange     => C4::Context->preference("OpacPasswordChange"),
            OPACPatronDetails      => C4::Context->preference("OPACPatronDetails"),
            OPACPrivacy            => C4::Context->preference("OPACPrivacy"),
            OPACFinesTab           => C4::Context->preference("OPACFinesTab"),
            OpacTopissue           => C4::Context->preference("OpacTopissue"),
            'Version'              => C4::Context->preference('Version'),
            hidelostitems          => C4::Context->preference("hidelostitems"),
            mylibraryfirst         => ( C4::Context->preference("SearchMyLibraryFirst") && C4::Context->userenv )
            ? C4::Context->userenv->{'branch'}
            : '',
            opacbookbag                           => "" . C4::Context->preference("opacbookbag"),
            OpacFavicon                           => C4::Context->preference("OpacFavicon"),
            opaclanguagesdisplay                  => "" . C4::Context->preference("opaclanguagesdisplay"),
            opacreadinghistory                    => C4::Context->preference("opacreadinghistory"),
            opacuserlogin                         => "" . C4::Context->preference("opacuserlogin"),
            OpenLibrarySearch                     => C4::Context->preference("OpenLibrarySearch"),
            ShowReviewer                          => C4::Context->preference("ShowReviewer"),
            ShowReviewerPhoto                     => C4::Context->preference("ShowReviewerPhoto"),
            suggestion                            => $can_make_suggestions,
            virtualshelves                        => "" . C4::Context->preference("virtualshelves"),
            OPACSerialIssueDisplayCount           => C4::Context->preference("OPACSerialIssueDisplayCount"),
            SyndeticsClientCode                   => C4::Context->preference("SyndeticsClientCode"),
            SyndeticsEnabled                      => C4::Context->preference("SyndeticsEnabled"),
            SyndeticsCoverImages                  => C4::Context->preference("SyndeticsCoverImages"),
            SyndeticsTOC                          => C4::Context->preference("SyndeticsTOC"),
            SyndeticsSummary                      => C4::Context->preference("SyndeticsSummary"),
            SyndeticsEditions                     => C4::Context->preference("SyndeticsEditions"),
            SyndeticsExcerpt                      => C4::Context->preference("SyndeticsExcerpt"),
            SyndeticsReviews                      => C4::Context->preference("SyndeticsReviews"),
            SyndeticsAuthorNotes                  => C4::Context->preference("SyndeticsAuthorNotes"),
            SyndeticsAwards                       => C4::Context->preference("SyndeticsAwards"),
            SyndeticsSeries                       => C4::Context->preference("SyndeticsSeries"),
            SyndeticsCoverImageSize               => C4::Context->preference("SyndeticsCoverImageSize"),
            OPACLocalCoverImages                  => C4::Context->preference("OPACLocalCoverImages"),
            PatronSelfRegistration                => C4::Context->preference("PatronSelfRegistration"),
            PatronSelfRegistrationDefaultCategory => C4::Context->preference("PatronSelfRegistrationDefaultCategory"),
            useDischarge                          => C4::Context->preference('useDischarge'),
        );

        $template->param( OpacPublic => '1' ) if ( $user || C4::Context->preference("OpacPublic") );
    }

    # Check if we were asked using parameters to force a specific language
    if ( defined $in->{'query'}->param('language') ) {

        # Extract the language, let C4::Languages::getlanguage choose
        # what to do
        my $language       = C4::Languages::getlanguage( $in->{'query'} );
        my $languagecookie = C4::Templates::getlanguagecookie( $in->{'query'}, $language );
        $cookie = $cookie_mgr->replace_in_list( $cookie, $languagecookie );
    }

    # user info
    $template->param( loggedinusername => $user )
        ;    # OBSOLETE - Do not reuse this in template, use logged_in_user.userid instead
    $template->param( loggedinusernumber => $borrowernumber )
        ;    # FIXME Should be replaced with logged_in_user.borrowernumber
    $template->param( logged_in_user => $patron );
    $template->param( sessionID      => $sessionID );

    return ( $template, $borrowernumber, $cookie, $flags );
}

=head2 checkauth

  ($userid, $cookie, $sessionID) = &checkauth($query, $noauth, $flagsrequired, $type);

Verifies that the user is authorized to run this script.  If
the user is authorized, a (userid, cookie, session-id, flags)
quadruple is returned.  If the user is not authorized but does
not have the required privilege (see $flagsrequired below), it
displays an error page and exits.  Otherwise, it displays the
login page and exits.

Note that C<&checkauth> will return if and only if the user
is authorized, so it should be called early on, before any
unfinished operations (e.g., if you've opened a file, then
C<&checkauth> won't close it for you).

C<$query> is the CGI object for the script calling C<&checkauth>.

The C<$noauth> argument is optional. If it is set, then no
authorization is required for the script.

C<&checkauth> fetches user and session information from C<$query> and
ensures that the user is authorized to run scripts that require
authorization.

The C<$flagsrequired> argument specifies the required privileges
the user must have if the username and password are correct.
It should be specified as a reference-to-hash; keys in the hash
should be the "flags" for the user, as specified in the Members
intranet module. Any key specified must correspond to a "flag"
in the userflags table. E.g., { circulate => 1 } would specify
that the user must have the "circulate" privilege in order to
proceed. To make sure that access control is correct, the
C<$flagsrequired> parameter must be specified correctly.

Koha also has a concept of sub-permissions, also known as
granular permissions.  This makes the value of each key
in the C<flagsrequired> hash take on an additional
meaning, i.e.,

 1

The user must have access to all subfunctions of the module
specified by the hash key.

 *

The user must have access to at least one subfunction of the module
specified by the hash key.

 specific permission, e.g., 'export_catalog'

The user must have access to the specific subfunction list, which
must correspond to a row in the permissions table.

The C<$type> argument specifies whether the template should be
retrieved from the opac or intranet directory tree.  "opac" is
assumed if it is not specified; however, if C<$type> is specified,
"intranet" is assumed if it is not "opac".

If C<$query> does not have a valid session ID associated with it
(i.e., the user has not logged in) or if the session has expired,
C<&checkauth> presents the user with a login page (from the point of
view of the original script, C<&checkauth> does not return). Once the
user has authenticated, C<&checkauth> restarts the original script
(this time, C<&checkauth> returns).

The login page is provided using a HTML::Template, which is set in the
systempreferences table or at the top of this file. The variable C<$type>
selects which template to use, either the opac or the intranet
authentification template.

C<&checkauth> returns a user ID, a cookie, and a session ID. The
cookie should be sent back to the browser; it verifies that the user
has authenticated.

=cut

sub _version_check {
    my $type  = shift;
    my $query = shift;
    my $version;

    # If version syspref is unavailable, it means Koha is being installed,
    # and so we must redirect to OPAC maintenance page or to the WebInstaller
    # also, if OpacMaintenance is ON, OPAC should redirect to maintenance
    if ( C4::Context->preference('OpacMaintenance') && $type eq 'opac' ) {
        warn "OPAC Install required, redirecting to maintenance";
        print $query->redirect("/cgi-bin/koha/maintenance.pl");
        safe_exit;
    }
    unless ( $version = C4::Context->preference('Version') ) {    # assignment, not comparison
        if ( $type ne 'opac' ) {
            warn "Install required, redirecting to Installer";
            print $query->redirect("/cgi-bin/koha/installer/install.pl");
        } else {
            warn "OPAC Install required, redirecting to maintenance";
            print $query->redirect("/cgi-bin/koha/maintenance.pl");
        }
        safe_exit;
    }

    # check that database and koha version are the same
    # there is no DB version, it's a fresh install,
    # go to web installer
    # there is a DB version, compare it to the code version
    my $kohaversion = Koha::version();

    # remove the 3 last . to have a Perl number
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    Koha::Logger->get->debug("kohaversion : $kohaversion");
    if ( $version < $kohaversion ) {
        my $warning = "Database update needed, redirecting to %s. Database is $version and Koha is $kohaversion";
        if ( $type ne 'opac' ) {
            warn sprintf( $warning, 'Installer' );
            print $query->redirect("/cgi-bin/koha/installer/install.pl");
        } else {
            warn sprintf( "OPAC: " . $warning, 'maintenance' );
            print $query->redirect("/cgi-bin/koha/maintenance.pl");
        }
        safe_exit;
    }
}

sub _timeout_syspref {
    my $default_timeout = 600;
    my $timeout         = C4::Context->preference('timeout') || $default_timeout;

    # value in days, convert in seconds
    if ( $timeout =~ /^(\d+)[dD]$/ ) {
        $timeout = $1 * 86400;
    }

    # value in hours, convert in seconds
    elsif ( $timeout =~ /^(\d+)[hH]$/ ) {
        $timeout = $1 * 3600;
    } elsif ( $timeout !~ m/^\d+$/ ) {
        warn "The value of the system preference 'timeout' is not correct, defaulting to $default_timeout";
        $timeout = $default_timeout;
    }

    return $timeout;
}

sub checkauth {
    my $query = shift;

    # Get shibboleth login attribute
    my $shib       = C4::Context->preference('ShibbolethAuthentication') && shib_ok();
    my $shib_login = $shib ? get_login_shib() : undef;

    # $authnotrequired will be set for scripts which will run without authentication
    my $authnotrequired = shift;
    my $flagsrequired   = shift;
    my $type            = shift;
    my $emailaddress    = shift;
    my $template_name   = shift;
    my $params          = shift || {};    # do_not_print, skip_csrf_check

    my $skip_csrf_check = $params->{skip_csrf_check} || 0;
    $type = 'opac' unless $type;

    if ( $type eq 'opac' && !C4::Context->preference("OpacPublic") ) {
        my @allowed_scripts_for_private_opac = qw(
            opac-memberentry.tt
            opac-registration-email-sent.tt
            opac-registration-confirmation.tt
            opac-memberentry-update-submitted.tt
            opac-password-recovery.tt
            opac-reset-password.tt
            ilsdi.tt
        );
        $authnotrequired = 0 unless grep { $_ eq $template_name } @allowed_scripts_for_private_opac;
    }

    my $timeout = _timeout_syspref();

    my $cookie_mgr = Koha::CookieManager->new;

    _version_check( $type, $query );

    # state variables
    my $auth_state = 'failed';
    my %info;
    my ( $userid, $cookie, $sessionID, $flags );
    $cookie = [];
    my $logout = $query->param('logout.x');

    my $anon_search_history;
    my $cas_ticket = '';

    # This parameter is the name of the CAS server we want to authenticate against,
    # when using authentication against multiple CAS servers, as configured in Auth_cas_servers.yaml
    my $casparam = $query->param('cas');
    my $q_userid = $query->param('login_userid') // '';

    my $session;
    my $invalid_otp_token;
    my $require_2FA = (
        $type ne "opac"    # Only available for the staff interface
            && C4::Context->preference('TwoFactorAuthentication') ne "disabled"
        )                  # If "enabled" or "enforced"
        ? 1 : 0;

    # Basic authentication is incompatible with the use of Shibboleth,
    # as Shibboleth may return REMOTE_USER as a Shibboleth attribute,
    # and it may not be the attribute we want to use to match the koha login.
    #
    # Also, do not consider an empty REMOTE_USER.
    #
    # Finally, after those tests, we can assume (although if it would be better with
    # a syspref) that if we get a REMOTE_USER, that's from basic authentication,
    # and we can affect it to $userid.
    if ( !$shib and defined( $ENV{'REMOTE_USER'} ) and $ENV{'REMOTE_USER'} ne '' and $userid = $ENV{'REMOTE_USER'} ) {

        # Using Basic Authentication, no cookies required
        $cookie = $cookie_mgr->replace_in_list(
            $cookie,
            $query->cookie(
                -name     => 'CGISESSID',
                -value    => '',
                -HttpOnly => 1,
                -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                -sameSite => 'Lax',
            )
        );
    } elsif ($emailaddress) {

        # the Google OpenID Connect passes an email address
    } elsif ( $sessionID = $query->cookie("CGISESSID") ) {    # assignment, not comparison
        my ( $return, $more_info );

        # NOTE: $flags in the following call is still undefined !
        ( $return, $session, $more_info ) = check_cookie_auth(
            $sessionID, $flags,
            { remote_addr => $ENV{REMOTE_ADDR}, skip_version_check => 1 }
        );

        if ( $return eq 'ok' || $return eq 'additional-auth-needed' ) {
            $userid = $session->param('id');
        }

        $auth_state =
              $return eq 'ok'                     ? 'completed'
            : $return eq 'additional-auth-needed' ? 'additional-auth-needed'
            :                                       'failed';

        # We are at the second screen if the waiting-for-2FA is set in session
        # and otp_token param has been passed
        if (   $require_2FA
            && $auth_state eq 'additional-auth-needed'
            && ( my $otp_token = $query->param('otp_token') ) )
        {
            my $patron   = Koha::Patrons->find( { userid => $userid } );
            my $auth     = Koha::Auth::TwoFactorAuth->new( { patron => $patron } );
            my $verified = $auth->verify($otp_token);
            $auth->clear;
            if ($verified) {

                # The token is correct, the user is fully logged in!
                $auth_state = 'completed';
                $session->param( 'waiting-for-2FA',       0 );
                $session->param( 'waiting-for-2FA-setup', 0 );

                # This is an ugly trick to pass the test
                # $query->param('koha_login_context') && ( $q_userid ne $userid )
                # few lines later
                $q_userid = $userid;
            } else {
                $invalid_otp_token = 1;
            }
        }

        if ( $auth_state eq 'completed' ) {
            Koha::Logger->get->debug(
                sprintf "AUTH_SESSION: (%s)\t%s %s - %s",
                map { $session->param($_) || q{} } qw(cardnumber firstname surname branch)
            );

            if (   ( $query->param('koha_login_context') && ( $q_userid ne $userid ) )
                || ( $cas && $query->param('ticket') && !C4::Context->userenv->{'id'} )
                || ( $shib && $shib_login && !$logout && !C4::Context->userenv->{'id'} ) )
            {

                #if a user enters an id ne to the id in the current session, we need to log them in...
                #first we need to clear the anonymous session...
                $anon_search_history = $session->param('search_history');
                $session->delete();
                $session->flush;
                $cookie = $cookie_mgr->clear_unless( $query->cookie, @$cookie );
                C4::Context::unset_userenv();
                $sessionID = undef;
                undef $userid;    # IMPORTANT: this assures us a new session in code below
                $auth_state = 'failed';
            } elsif ( !$logout ) {

                $cookie = $cookie_mgr->replace_in_list(
                    $cookie,
                    $query->cookie(
                        -name     => 'CGISESSID',
                        -value    => $session->id,
                        -HttpOnly => 1,
                        -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                        -sameSite => 'Lax',
                    )
                );

                $flags = haspermission( $userid, $flagsrequired );
                unless ($flags) {
                    $auth_state = 'failed';
                    $info{'nopermission'} = 1;
                }
            }
        } elsif ( !$logout ) {
            if ( $return eq 'expired' ) {
                $info{timed_out} = 1;
            } elsif ( $return eq 'restricted' ) {
                $info{oldip}        = $more_info->{old_ip};
                $info{newip}        = $more_info->{new_ip};
                $info{different_ip} = 1;
            } elsif ( $return eq 'password_expired' ) {
                $info{password_has_expired} = 1;
            }
        }
    }

    my $request_method = $query->request_method // q{};

    if ( $auth_state eq 'failed' || $logout ) {
        $sessionID = undef;
        $userid    = undef;
    }

    if ($logout) {

        # voluntary logout the user
        # check wether the user was using their shibboleth session or a local one
        my $shibSuccess = C4::Context->userenv ? C4::Context->userenv->{'shibboleth'} : undef;
        if ($session) {
            $session->delete();
            $session->flush;
        }
        C4::Context::unset_userenv();
        $cookie = $cookie_mgr->clear_unless( $query->cookie, @$cookie );

        if ( $cas and $caslogout ) {
            logout_cas( $query, $type );
        }

        # If we are in a shibboleth session (shibboleth is enabled, a shibboleth match attribute is set and matches koha matchpoint)
        if ( $shib and $shib_login and $shibSuccess ) {
            logout_shib($query);
        }

        $session    = undef;
        $auth_state = 'logout';
    }

    unless ($userid) {

        #we initiate a session prior to checking for a username to allow for anonymous sessions...
        if ( !$session or !$sessionID ) {    # if we cleared sessionID, we need a new session
            $session = get_session() or die "Auth ERROR: Cannot get_session()";
        }

        # Save anonymous search history in new session so it can be retrieved
        # by get_template_and_user to store it in user's search history after
        # a successful login.
        if ($anon_search_history) {
            $session->param( 'search_history', $anon_search_history );
        }

        $sessionID = $session->id;
        $cookie    = $cookie_mgr->replace_in_list(
            $cookie,
            $query->cookie(
                -name     => 'CGISESSID',
                -value    => $sessionID,
                -HttpOnly => 1,
                -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                -sameSite => 'Lax',
            )
        );
        my $pki_field = C4::Context->preference('AllowPKIAuth');
        if ( !defined($pki_field) ) {
            print STDERR "ERROR: Missing system preference AllowPKIAuth.\n";
            $pki_field = 'None';
        }
        if (   ( $cas && $query->param('ticket') )
            || $q_userid
            || ( $shib && $shib_login )
            || $pki_field ne 'None'
            || $emailaddress )
        {
            my $password    = $query->param('login_password');
            my $shibSuccess = 0;
            my ( $return, $cardnumber );

            # If shib is enabled and we have a shib login, does the login match a valid koha user
            if ( $shib && $shib_login ) {
                my $retuserid;

                # Do not pass password here, else shib will not be checked in checkpw.
                ( $return, $cardnumber, $retuserid ) = checkpw( $q_userid, undef, $query );
                $userid                   = $retuserid;
                $shibSuccess              = $return;
                $info{'invalidShibLogin'} = 1 unless ($return);
            }

            # If shib login and match were successful, skip further login methods
            unless ($shibSuccess) {
                if ( $cas && $query->param('ticket') ) {
                    my $retuserid;
                    my $patron;
                    ( $return, $cardnumber, $retuserid, $patron, $cas_ticket ) =
                        checkpw( $userid, $password, $query, $type );
                    $userid = $retuserid;
                    $info{'invalidCasLogin'} = 1 unless ($return);

                } elsif ($emailaddress) {
                    my $value = $emailaddress;

                    # If we're looking up the email, there's a chance that the person
                    # doesn't have a userid. So if there is none, we pass along the
                    # borrower number, and the bits of code that need to know the user
                    # ID will have to be smart enough to handle that.
                    my $patrons = Koha::Patrons->search( { email => $value } );
                    if ( $patrons->count ) {

                        # First the userid, then the borrowernum
                        my $patron = $patrons->next;
                        $value = $patron->userid || $patron->borrowernumber;
                    } else {
                        undef $value;
                    }
                    $return = $value ? 1 : 0;
                    $userid = $value;

                } elsif (
                    ( $pki_field eq 'Common Name' && $ENV{'SSL_CLIENT_S_DN_CN'} )
                    || (   $pki_field eq 'emailAddress'
                        && $ENV{'SSL_CLIENT_S_DN_Email'} )
                    )
                {
                    my $value;
                    if ( $pki_field eq 'Common Name' ) {
                        $value = $ENV{'SSL_CLIENT_S_DN_CN'};
                    } elsif ( $pki_field eq 'emailAddress' ) {
                        $value = $ENV{'SSL_CLIENT_S_DN_Email'};

                        # If we're looking up the email, there's a chance that the person
                        # doesn't have a userid. So if there is none, we pass along the
                        # borrower number, and the bits of code that need to know the user
                        # ID will have to be smart enough to handle that.
                        my $patrons = Koha::Patrons->search( { email => $value } );
                        if ( $patrons->count ) {

                            # First the userid, then the borrowernum
                            my $patron = $patrons->next;
                            $value = $patron->userid || $patron->borrowernumber;
                        } else {
                            undef $value;
                        }
                    }

                    $return = $value ? 1 : 0;
                    $userid = $value;

                } else {
                    my $retuserid;

                    if (
                        $request_method eq 'POST'
                        || ( C4::Context->preference('AutoSelfCheckID')
                            && $q_userid eq C4::Context->preference('AutoSelfCheckID') )
                        )
                    {
                        my $patron;

                        ( $return, $cardnumber, $retuserid, $patron, $cas_ticket ) =
                            checkpw( $q_userid, $password, $query, $type );
                        $userid = $retuserid if ($retuserid);
                        $info{'invalid_username_or_password'} = 1 unless ($return);
                    }
                }
            }

            # If shib configured and shibOnly enabled, we should ignore anything other than a shibboleth type login.
            if (
                   $shib
                && !$shibSuccess
                && (
                    ( ( $type eq 'opac' ) && Koha::ShibbolethConfigs->get_configuration->get_value('force_opac_sso') )
                    || ( ( $type ne 'opac' )
                        && Koha::ShibbolethConfigs->get_configuration->get_value('force_staff_sso') )
                )
                )
            {
                $return = 0;
            }

            # $return: 1 = valid user
            if ( $return && $return > 0 ) {

                if ( $flags = haspermission( $userid, $flagsrequired ) ) {
                    $auth_state = "logged_in";
                } else {
                    $auth_state = 'failed';

                    # FIXME We could add $return = 0; or even delete the session?
                    # Currently return == 1 and we will fill session info later on,
                    # although we do present an authorization failure. (Yes, the
                    # authentication was actually correct.)
                    $info{'nopermission'} = 1;
                    C4::Context::unset_userenv();
                }
                my (
                    $borrowernumber, $firstname,   $surname,      $userflags,
                    $branchcode,     $branchname,  $emailaddress, $desk_id,
                    $desk_name,      $register_id, $register_name
                );

                if ( $return == 1 ) {
                    my $select = "
                    SELECT borrowernumber, firstname, surname, flags, borrowers.branchcode,
                    branches.branchname    as branchname, email
                    FROM borrowers
                    LEFT JOIN branches on borrowers.branchcode=branches.branchcode
                    ";
                    my $dbh = C4::Context->dbh;
                    my $sth = $dbh->prepare("$select where userid=?");
                    $sth->execute($userid);
                    unless ( $sth->rows ) {
                        $sth = $dbh->prepare("$select where cardnumber=?");
                        $sth->execute($cardnumber);

                        unless ( $sth->rows ) {
                            $sth->execute($userid);
                        }
                    }
                    if ( $sth->rows ) {
                        (
                            $borrowernumber, $firstname,  $surname, $userflags,
                            $branchcode,     $branchname, $emailaddress
                        ) = $sth->fetchrow;
                    }

                    # launch a sequence to check if we have a ip for the branch, i
                    # if we have one we replace the branchcode of the userenv by the branch bound in the ip.

                    my $ip = $ENV{'REMOTE_ADDR'};

                    # if they specify at login, use that
                    my $patron = Koha::Patrons->find( { userid => $userid } );
                    if ( $query->param('branch')
                        && ( haspermission( $userid, { 'loggedinlibrary' => 1 } ) || $patron->is_superlibrarian ) )
                    {
                        $branchcode = $query->param('branch');
                        my $library = Koha::Libraries->find($branchcode);
                        $branchname = $library ? $library->branchname : '';
                    }
                    if ( $query->param('desk_id') ) {
                        $desk_id = $query->param('desk_id');
                        my $desk = Koha::Desks->find($desk_id);
                        $desk_name = $desk ? $desk->desk_name : '';
                    }
                    if ( C4::Context->preference('UseCashRegisters') ) {
                        my $register =
                            $query->param('register_id')
                            ? Koha::Cash::Registers->find( $query->param('register_id') )
                            : Koha::Cash::Registers->search(
                            { branch => $branchcode, branch_default => 1 },
                            { rows   => 1 }
                        )->single;
                        $register_id   = $register->id   if ($register);
                        $register_name = $register->name if ($register);
                    }
                    if ( $type ne 'opac' ) {
                        my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search->as_list };
                        if ( C4::Context->preference('StaffLoginRestrictLibraryByIP') ) {

                            # we have to check they are coming from the right ip range
                            my $domain = $branches->{$branchcode}->{'branchip'} // q{};
                            $domain =~ s|\.\*||g;
                            $domain =~ s/\s+//g;
                            if ( $domain && $ip !~ /^$domain/ ) {
                                $cookie = $cookie_mgr->replace_in_list(
                                    $cookie,
                                    $query->cookie(
                                        -name     => 'CGISESSID',
                                        -value    => '',
                                        -HttpOnly => 1,
                                        -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                                        -sameSite => 'Lax',
                                    )
                                );
                                $info{'wrongip'} = 1;
                                $auth_state = "failed";
                            }
                        }

                        if (
                            # If StaffLoginLibraryBasedOnIP is enabled we will try to find a branch
                            # matching your ip, regardless of the choice you have passed in
                            (
                                  !C4::Context->preference('StaffLoginRestrictLibraryByIP')
                                && C4::Context->preference('StaffLoginLibraryBasedOnIP')
                            )

                            # When StaffLoginRestrictLibraryByIP is enabled we will not choose a branch matching IP
                            # if your selected branch has no IP set
                            || (   C4::Context->preference('StaffLoginRestrictLibraryByIP')
                                && $auth_state ne 'failed'
                                && $branches->{$branchcode}->{'branchip'} )
                            )
                        {
                            my @branchcodes = sort { lc $a cmp lc $b } keys %$branches;
                            foreach my $br ( uniq( $branchcode, @branchcodes ) ) {

                                #     now we work with the treatment of ip
                                my $domain = $branches->{$br}->{'branchip'};
                                if ( $domain && $ip =~ /^$domain/ ) {
                                    $branchcode = $branches->{$br}->{'branchcode'};

                                    # new op dev : add the branchname to the cookie
                                    $branchname = $branches->{$br}->{'branchname'};
                                    last;
                                }
                            }
                        }
                    }

                    my $is_sco_user = 0;
                    if ( $query->param('sco_user_login') && ( $query->param('sco_user_login') eq '1' ) ) {
                        $is_sco_user = 1;
                    }

                    $session->param( 'number',        $borrowernumber );
                    $session->param( 'id',            $userid );
                    $session->param( 'cardnumber',    $cardnumber );
                    $session->param( 'firstname',     $firstname );
                    $session->param( 'surname',       $surname );
                    $session->param( 'branch',        $branchcode );
                    $session->param( 'branchname',    $branchname );
                    $session->param( 'desk_id',       $desk_id );
                    $session->param( 'desk_name',     $desk_name );
                    $session->param( 'flags',         $userflags );
                    $session->param( 'emailaddress',  $emailaddress );
                    $session->param( 'ip',            $session->remote_addr() );
                    $session->param( 'lasttime',      time() );
                    $session->param( 'interface',     $type );
                    $session->param( 'shibboleth',    $shibSuccess );
                    $session->param( 'register_id',   $register_id );
                    $session->param( 'register_name', $register_name );
                    $session->param( 'sco_user',      $is_sco_user );
                }
                $session->param( 'cas_ticket', $cas_ticket ) if $cas_ticket;
                C4::Context->set_userenv(
                    $session->param('number'),       $session->param('id'),
                    $session->param('cardnumber'),   $session->param('firstname'),
                    $session->param('surname'),      $session->param('branch'),
                    $session->param('branchname'),   $session->param('flags'),
                    $session->param('emailaddress'), $session->param('shibboleth'),
                    $session->param('desk_id'),      $session->param('desk_name'),
                    $session->param('register_id'),  $session->param('register_name')
                );

            }

            # $return: 0 = invalid user
            # reset to anonymous session
            else {
                if ($userid) {
                    $info{'invalid_username_or_password'} = 1;
                    C4::Context::unset_userenv();
                }
                $session->param( 'lasttime',    time() );
                $session->param( 'ip',          $session->remote_addr() );
                $session->param( 'sessiontype', 'anon' );
                $session->param( 'interface',   $type );
            }
        }    # END if ( $q_userid
        elsif ( $type eq "opac" ) {

            # anonymous sessions are created only for the OPAC

            # setting a couple of other session vars...
            $session->param( 'ip',          $session->remote_addr() );
            $session->param( 'lasttime',    time() );
            $session->param( 'sessiontype', 'anon' );
            $session->param( 'interface',   $type );
        }
        $session->flush;
    }    # END unless ($userid)

    if ( $auth_state eq 'logged_in' ) {
        $auth_state = 'completed';

        # Auth is completed unless an additional auth is needed
        if ($require_2FA) {
            my $patron = Koha::Patrons->find( { userid => $userid } );
            if ( C4::Context->preference('TwoFactorAuthentication') eq "enforced"
                && $patron->auth_method eq 'password' )
            {
                $auth_state = 'setup-additional-auth-needed';
                $session->param( 'waiting-for-2FA-setup', 1 );
                %info = ();    # We remove the warnings/errors we may have set incorrectly before
            } elsif ( $patron->auth_method eq 'two-factor' ) {

                # Ask for the OTP token
                $auth_state = 'additional-auth-needed';
                $session->param( 'waiting-for-2FA', 1 );
                %info = ();    # We remove the warnings/errors we may have set incorrectly before
            }
        }
    }

    # finished authentification, now respond
    if ( $auth_state eq 'completed' || $authnotrequired ) {

        # successful login
        unless (@$cookie) {
            $cookie = $cookie_mgr->replace_in_list(
                $cookie,
                $query->cookie(
                    -name     => 'CGISESSID',
                    -value    => '',
                    -HttpOnly => 1,
                    -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                    -sameSite => 'Lax',
                )
            );
        }

        my $patron = $userid ? Koha::Patrons->find( { userid => $userid } ) : undef;
        $patron->update_lastseen('login') if $patron;

        # FIXME This is only needed for scripts not using plack
        my $op = $query->param('op');
        if ( defined $op && $op =~ m{^cud-} ) {
            die "Cannot use GET for this request"
                if $request_method eq 'GET';
        }

        if ( !$skip_csrf_check && $query->param('invalid_csrf_token') ) {
            Koha::Exceptions::Token::WrongCSRFToken->throw;
        }

        # In case, that this request was a login attempt, we want to prevent that users can repost the opac login
        # request. We therefore redirect the user to the requested page again without the login parameters.
        # See Post/Redirect/Get (PRG) design pattern: https://en.wikipedia.org/wiki/Post/Redirect/Get
        if (   $type eq "opac"
            && $query->param('koha_login_context')
            && $query->param('koha_login_context') ne 'sco'
            && $query->param('login_password')
            && $query->param('login_userid') )
        {
            my $uri = URI->new( $query->url( -relative => 1, -query_string => 1 ) );
            $uri->query_param_delete('login_userid');
            $uri->query_param_delete('login_password');
            $uri->query_param_delete('koha_login_context');
            $uri->query_param_delete('op');
            $uri->query_param_delete('csrf_token');
            unless ( $params->{do_not_print} ) {
                print $query->redirect( -uri => $uri->as_string, -cookie => $cookie, -status => '303 See other' );
                safe_exit;
            }
        }

        return ( $userid, $cookie, $sessionID, $flags );
    }

    #
    #
    # AUTH rejected, show the login/password template, after checking the DB.
    #
    #

    my $patron = Koha::Patrons->find( { userid => $q_userid } );    # Not necessary logged in!

    # get the inputs from the incoming query
    my @inputs          = ();
    my @inputs_to_clean = qw( login_userid login_password ticket logout.x otp_token );
    foreach my $name ( param $query) {
        next if grep { $name eq $_ } @inputs_to_clean;
        my @value = $query->multi_param($name);
        push @inputs, { name => $name, value => $_ } for @value;
    }

    my $LibraryNameTitle = C4::Context->preference("LibraryName");
    $LibraryNameTitle =~ s/<(?:\/?)(?:br|p)\s*(?:\/?)>/ /sgi;
    $LibraryNameTitle =~ s/<(?:[^<>'"]|'(?:[^']*)'|"(?:[^"]*)")*>//sg;

    my $auth_error         = $query->param('auth_error');
    my $auth_template_name = ( $type eq 'opac' ) ? 'opac-auth.tt' : 'auth.tt';
    my $template           = C4::Templates::gettemplate( $auth_template_name, $type, $query );

    my $borrowernumber      = $patron and $patron->borrowernumber;
    my $anonymous_patron    = C4::Context->preference('AnonymousPatron');
    my $is_anonymous_patron = $patron && ( $patron->borrowernumber eq $anonymous_patron );

    $template->param(
        login                                 => 1,
        INPUTS                                => \@inputs,
        script_name                           => get_script_name(),
        casAuthentication                     => C4::Context->preference("casAuthentication"),
        shibbolethAuthentication              => $shib,
        suggestion                            => C4::Context->preference("suggestion"),
        virtualshelves                        => C4::Context->preference("virtualshelves"),
        LibraryName                           => "" . C4::Context->preference("LibraryName"),
        LibraryNameTitle                      => "" . $LibraryNameTitle,
        opacuserlogin                         => C4::Context->preference("opacuserlogin"),
        OpacFavicon                           => C4::Context->preference("OpacFavicon"),
        opacreadinghistory                    => C4::Context->preference("opacreadinghistory"),
        opaclanguagesdisplay                  => C4::Context->preference("opaclanguagesdisplay"),
        opacbookbag                           => "" . C4::Context->preference("opacbookbag"),
        OpacCloud                             => C4::Context->preference("OpacCloud"),
        OpacTopissue                          => C4::Context->preference("OpacTopissue"),
        OpacAuthorities                       => C4::Context->preference("OpacAuthorities"),
        OpacBrowser                           => C4::Context->preference("OpacBrowser"),
        TagsEnabled                           => C4::Context->preference("TagsEnabled"),
        intranetcolorstylesheet               => C4::Context->preference("intranetcolorstylesheet"),
        intranetstylesheet                    => C4::Context->preference("intranetstylesheet"),
        IntranetNav                           => C4::Context->preference("IntranetNav"),
        IntranetFavicon                       => C4::Context->preference("IntranetFavicon"),
        IntranetUserCSS                       => C4::Context->preference("IntranetUserCSS"),
        IntranetUserJS                        => C4::Context->preference("IntranetUserJS"),
        IndependentBranches                   => C4::Context->preference("IndependentBranches"),
        StaffLoginRestrictLibraryByIP         => C4::Context->preference("StaffLoginRestrictLibraryByIP"),
        wrongip                               => $info{'wrongip'},
        PatronSelfRegistration                => C4::Context->preference("PatronSelfRegistration"),
        PatronSelfRegistrationDefaultCategory => C4::Context->preference("PatronSelfRegistrationDefaultCategory"),
        opac_css_override                     => $ENV{'OPAC_CSS_OVERRIDE'},
        too_many_login_attempts               => ( $patron and $patron->account_locked ),
        password_has_expired                  => ( $patron and $patron->password_expired ),
        is_anonymous_patron                   => ($is_anonymous_patron),
        password_expiration_date              => ( $patron and $patron->password_expiration_date ),
        date_enrolled                         => ( $patron and $patron->dateenrolled ),
        auth_error                            => $auth_error,
    );

    $template->param( SCO_login   => 1 ) if ( $query->param('sco_user_login') );
    $template->param( SCI_login   => 1 ) if ( $query->param('sci_user_login') );
    $template->param( OpacPublic  => C4::Context->preference("OpacPublic") );
    $template->param( loginprompt => 1 ) unless $info{'nopermission'};
    if ( $auth_state eq 'additional-auth-needed' ) {
        my $patron = Koha::Patrons->find( { userid => $userid } );
        $template->param(
            TwoFA_prompt         => 1,
            invalid_otp_token    => $invalid_otp_token,
            notice_email_address => $patron->notice_email_address,    # We could also pass logged_in_user if necessary
        );
    }

    if ( $auth_state eq 'setup-additional-auth-needed' ) {
        $template->param(
            TwoFA_setup => 1,
        );
    }

    if ( $type eq 'opac' ) {
        require Koha::Virtualshelves;
        my $some_public_shelves = Koha::Virtualshelves->get_some_shelves(
            {
                public => 1,
            }
        );
        $template->param(
            some_public_shelves => $some_public_shelves,
        );
    }

    if ($cas) {

        # Is authentication against multiple CAS servers enabled?
        require C4::Auth_with_cas;
        if ( multipleAuth() && !$casparam ) {
            my $casservers = getMultipleAuth();
            my @tmplservers;
            foreach my $key ( keys %$casservers ) {
                push @tmplservers, { name => $key, value => login_cas_url( $query, $key, $type ) . "?cas=$key" };
            }
            $template->param( casServersLoop => \@tmplservers );
        } else {
            $template->param(
                casServerUrl => login_cas_url( $query, undef, $type ),
            );
        }

        $template->param( invalidCasLogin => $info{'invalidCasLogin'} );
    }

    if ($shib) {

        #If shibOnly is enabled just go ahead and redirect directly
        if (   ( ( $type eq 'opac' ) && Koha::ShibbolethConfigs->get_configuration->get_value('force_opac_sso') )
            || ( ( $type ne 'opac' ) && Koha::ShibbolethConfigs->get_configuration->get_value('force_staff_sso') ) )
        {
            my $redirect_url = login_shib_url($query);
            print $query->redirect( -uri => "$redirect_url", -status => 303 );
            safe_exit;
        }

        $template->param(
            shibbolethAuthentication => $shib,
            shibbolethLoginUrl       => login_shib_url($query),
        );
    }

    if ( C4::Context->preference('GoogleOpenIDConnect') ) {
        if ( $query->param("OpenIDConnectFailed") ) {
            my $reason = $query->param('OpenIDConnectFailed');
            $template->param( invalidGoogleOpenIDConnectLogin => $reason );
        }
    }

    $template->param(
        LibraryName => C4::Context->preference("LibraryName"),
        %info,
        sessionID => $session->id,
    );

    if ( $params->{do_not_print} ) {

        # This must be used for testing purpose only!
        return ( undef, undef, undef, undef, $template );
    }

    print $query->header(
        {
            type              => 'text/html',
            charset           => 'utf-8',
            cookie            => $cookie,
            'X-Frame-Options' => 'SAMEORIGIN',
            -sameSite         => 'Lax'
        }
        ),
        $template->output;
    safe_exit;
}

=head2 check_api_auth

  ($status, $cookie, $sessionId) = check_api_auth($query, $userflags);

Given a CGI query containing the parameters 'userid' and 'password' and/or a session
cookie, determine if the user has the privileges specified by C<$userflags>.

C<check_api_auth> is is meant for authenticating users of web services, and
consequently will always return and will not attempt to redirect the user
agent.

If a valid session cookie is already present, check_api_auth will return a status
of "ok", the cookie, and the Koha session ID.

If no session cookie is present, check_api_auth will check the 'userid' and 'password
parameters and create a session cookie and Koha session if the supplied credentials
are OK.

Possible return values in C<$status> are:

=over

=item "ok" -- user authenticated; C<$cookie> and C<$sessionid> have valid values.

=item "failed" -- credentials are not correct; C<$cookie> and C<$sessionid> are undef

=item "maintenance" -- DB is in maintenance mode; no login possible at the moment

=item "expired -- session cookie has expired; API user should resubmit userid and password

=item "restricted" -- The IP has changed (if SessionRestrictionByIP)

=item "additional-auth-needed -- User is in an authentication process that is not finished

=back

=cut

sub check_api_auth {

    my $query         = shift;
    my $flagsrequired = shift;
    my $timeout       = _timeout_syspref();

    unless ( C4::Context->preference('Version') ) {

        # database has not been installed yet
        return ( "maintenance", undef, undef );
    }
    my $kohaversion = Koha::version();
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    if ( C4::Context->preference('Version') < $kohaversion ) {

        # database in need of version update; assume that
        # no API should be called while databsae is in
        # this condition.
        return ( "maintenance", undef, undef );
    }

    my ( $sessionID, $session );
    unless ( $query->param('login_userid') ) {
        $sessionID = $query->cookie("CGISESSID");
    }
    if ( $sessionID && not( $cas && $query->param('PT') ) ) {

        my $return;
        ( $return, $session, undef ) =
            check_cookie_auth( $sessionID, $flagsrequired, { remote_addr => $ENV{REMOTE_ADDR} } );

        return ( $return, undef, undef )    # Cookie auth failed
            if $return ne "ok";

        my $cookie = $query->cookie(
            -name     => 'CGISESSID',
            -value    => $session->id,
            -HttpOnly => 1,
            -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
            -sameSite => 'Lax'
        );
        return ( $return, $cookie, $session->id );    # return == 'ok' here

    } else {

        # new login
        my $userid   = $query->param('login_userid');
        my $password = $query->param('login_password');
        my ( $return, $cardnumber, $cas_ticket );

        # Proxy CAS auth
        if ( $cas && $query->param('PT') ) {
            my $retuserid;

            # In case of a CAS authentication, we use the ticket instead of the password
            my $PT = $query->param('PT');
            ( $return, $cardnumber, $userid, $cas_ticket ) = check_api_auth_cas( $PT, $query );    # EXTERNAL AUTH
        } else {

            # User / password auth
            unless ( $userid and $password ) {

                # caller did something wrong, fail the authenticateion
                return ( "failed", undef, undef );
            }
            my $newuserid;
            my $patron;
            ( $return, $cardnumber, $newuserid, $patron, $cas_ticket ) = checkpw( $userid, $password, $query );
        }

        if ( $return and haspermission( $userid, $flagsrequired ) ) {
            my $session = get_session("");
            return ( "failed", undef, undef ) unless $session;

            my $sessionID = $session->id;
            my $cookie    = $query->cookie(
                -name     => 'CGISESSID',
                -value    => $sessionID,
                -HttpOnly => 1,
                -secure   => ( C4::Context->https_enabled() ? 1 : 0 ),
                -sameSite => 'Lax'
            );
            if ( $return == 1 ) {
                my (
                    $borrowernumber, $firstname,  $surname,
                    $userflags,      $branchcode, $branchname,
                    $emailaddress
                );
                my $dbh = C4::Context->dbh;
                my $sth =
                    $dbh->prepare(
                    "select borrowernumber, firstname, surname, flags, borrowers.branchcode, branches.branchname as branchname, email from borrowers left join branches on borrowers.branchcode=branches.branchcode where userid=?"
                    );
                $sth->execute($userid);
                (
                    $borrowernumber, $firstname,  $surname,
                    $userflags,      $branchcode, $branchname,
                    $emailaddress
                    )
                    = $sth->fetchrow
                    if ( $sth->rows );

                unless ( $sth->rows ) {
                    my $sth = $dbh->prepare(
                        "select borrowernumber, firstname, surname, flags, borrowers.branchcode, branches.branchname as branchname, email from borrowers left join branches on borrowers.branchcode=branches.branchcode where cardnumber=?"
                    );
                    $sth->execute($cardnumber);
                    (
                        $borrowernumber, $firstname,  $surname,
                        $userflags,      $branchcode, $branchname,
                        $emailaddress
                        )
                        = $sth->fetchrow
                        if ( $sth->rows );

                    unless ( $sth->rows ) {
                        $sth->execute($userid);
                        (
                            $borrowernumber, $firstname,  $surname, $userflags,
                            $branchcode,     $branchname, $emailaddress
                            )
                            = $sth->fetchrow
                            if ( $sth->rows );
                    }
                }

                my $ip = $ENV{'REMOTE_ADDR'};

                # if they specify at login, use that
                if ( $query->param('branch') ) {
                    $branchcode = $query->param('branch');
                    my $library = Koha::Libraries->find($branchcode);
                    $branchname = $library ? $library->branchname : '';
                }
                my $branches = { map { $_->branchcode => $_->unblessed } Koha::Libraries->search->as_list };
                foreach my $br ( keys %$branches ) {

                    #     now we work with the treatment of ip
                    my $domain = $branches->{$br}->{'branchip'};
                    if ( $domain && $ip =~ /^$domain/ ) {
                        $branchcode = $branches->{$br}->{'branchcode'};

                        # new op dev : add the branchname to the cookie
                        $branchname = $branches->{$br}->{'branchname'};
                    }
                }
                $session->param( 'number',       $borrowernumber );
                $session->param( 'id',           $userid );
                $session->param( 'cardnumber',   $cardnumber );
                $session->param( 'firstname',    $firstname );
                $session->param( 'surname',      $surname );
                $session->param( 'branch',       $branchcode );
                $session->param( 'branchname',   $branchname );
                $session->param( 'flags',        $userflags );
                $session->param( 'emailaddress', $emailaddress );
                $session->param( 'ip',           $session->remote_addr() );
                $session->param( 'lasttime',     time() );
                $session->param( 'interface',    'api' );
            }
            $session->param( 'cas_ticket', $cas_ticket );
            C4::Context->set_userenv(
                $session->param('number'),       $session->param('id'),
                $session->param('cardnumber'),   $session->param('firstname'),
                $session->param('surname'),      $session->param('branch'),
                $session->param('branchname'),   $session->param('flags'),
                $session->param('emailaddress'), $session->param('shibboleth'),
                $session->param('desk_id'),      $session->param('desk_name'),
                $session->param('register_id'),  $session->param('register_name')
            );
            return ( "ok", $cookie, $sessionID );
        } else {
            return ( "failed", undef, undef );
        }
    }
}

=head2 check_cookie_auth

  ($status, $sessionId) = check_cookie_auth($cookie, $userflags);

Given a CGISESSID cookie set during a previous login to Koha, determine
if the user has the privileges specified by C<$userflags>. C<$userflags>
is passed unaltered into C<haspermission> and as such accepts all options
avaiable to that routine with the one caveat that C<check_api_auth> will
also allow 'undef' to be passed and in such a case the permissions check
will be skipped altogether.

C<check_cookie_auth> is meant for authenticating special services
such as tools/upload-file.pl that are invoked by other pages that
have been authenticated in the usual way.

Possible return values in C<$status> are:

=over

=item "ok" -- user authenticated; C<$sessionID> have valid values.

=item "anon" -- user not authenticated but valid for anonymous session.

=item "failed" -- credentials are not correct; C<$sessionid> are undef

=item "maintenance" -- DB is in maintenance mode; no login possible at the moment

=item "expired -- session cookie has expired; API user should resubmit userid and password

=item "restricted" -- The IP has changed (if SessionRestrictionByIP)

=back

=cut

sub check_cookie_auth {
    my $sessionID     = shift;
    my $flagsrequired = shift;
    my $params        = shift;

    my $remote_addr = $params->{remote_addr} || $ENV{REMOTE_ADDR};

    my $skip_version_check = $params->{skip_version_check};    # Only for checkauth

    unless ($skip_version_check) {
        unless ( C4::Context->preference('Version') ) {

            # database has not been installed yet
            return ( "maintenance", undef );
        }
        my $kohaversion = Koha::version();
        $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
        if ( C4::Context->preference('Version') < $kohaversion ) {

            # database in need of version update; assume that
            # no API should be called while databsae is in
            # this condition.
            return ( "maintenance", undef );
        }
    }

    # see if we have a valid session cookie already
    # however, if a userid parameter is present (i.e., from
    # a form submission, assume that any current cookie
    # is to be ignored
    unless ($sessionID) {
        return ( "failed", undef );
    }
    C4::Context::unset_userenv();
    my $session = get_session($sessionID);
    if ($session) {
        my $userid   = $session->param('id');
        my $ip       = $session->param('ip');
        my $lasttime = $session->param('lasttime');
        my $timeout  = _timeout_syspref();

        if ( !$lasttime || ( $lasttime < time() - $timeout ) ) {

            # time out
            $session->delete();
            $session->flush;
            return ( "expired", undef );

        } elsif ( C4::Context->preference('SessionRestrictionByIP') && $ip ne $remote_addr ) {

            # IP address changed
            $session->delete();
            $session->flush;
            return ( "restricted", undef, { old_ip => $ip, new_ip => $remote_addr } );

        } elsif ($userid) {
            $session->param( 'lasttime', time() );
            my $patron = Koha::Patrons->find( { userid => $userid } );

            # If the user modify their own userid
            # Better than 500 but we could do better
            unless ($patron) {
                $session->delete();
                $session->flush;
                return ( "expired", undef );
            }

            $patron = Koha::Patrons->find( { cardnumber => $userid } )
                unless $patron;
            return ( "password_expired", undef ) if $patron->password_expired;
            my $flags = defined($flagsrequired) ? haspermission( $userid, $flagsrequired ) : 1;
            if ($flags) {
                if ( !C4::Context->interface ) {

                    # No need to override the interface, most often set by get_template_and_user
                    C4::Context->interface( $session->param('interface') );
                }
                C4::Context->set_userenv(
                    $session->param('number'),       $session->param('id') // '',
                    $session->param('cardnumber'),   $session->param('firstname'),
                    $session->param('surname'),      $session->param('branch'),
                    $session->param('branchname'),   $session->param('flags'),
                    $session->param('emailaddress'), $session->param('shibboleth'),
                    $session->param('desk_id'),      $session->param('desk_name'),
                    $session->param('register_id'),  $session->param('register_name')
                );
                if ( C4::Context->preference('TwoFactorAuthentication') ne 'disabled' ) {
                    return ( "additional-auth-needed", $session )
                        if $session->param('waiting-for-2FA');

                    return ( "setup-additional-auth-needed", $session )
                        if $session->param('waiting-for-2FA-setup');
                }

                return ( "ok", $session );
            } else {
                $session->delete();
                $session->flush;
                return ( "failed", undef );
            }

        } else {
            C4::Context->interface( $session->param('interface') );
            C4::Context->set_userenv( undef, q{} );
            return ( "anon", $session );
        }
    } else {
        return ( "expired", undef );
    }
}

=head2 get_session

  use CGI::Session;
  my $session = get_session($sessionID);

Given a session ID, retrieve the CGI::Session object used to store
the session's state.  The session object can be used to store
data that needs to be accessed by different scripts during a
user's session.

If the C<$sessionID> parameter is an empty string, a new session
will be created.

=cut

#NOTE: We're keeping this for backwards compatibility
sub _get_session_params {
    return Koha::Session->_get_session_params();
}

#NOTE: We're keeping this for backwards compatibility
sub get_session {
    my $sessionID = shift;
    my $session   = Koha::Session->get_session( { sessionID => $sessionID } );
    return $session;
}

=head2 create_basic_session

my $session = create_basic_session({ patron => $patron, interface => $interface });

Creates a session and adds all basic parameters for a session to work

=cut

sub create_basic_session {
    my $params    = shift;
    my $patron    = $params->{patron};
    my $interface = $params->{interface};

    $interface = 'intranet' if $interface eq 'staff';

    my $session = get_session("");

    $session->param( 'number',       $patron->borrowernumber );
    $session->param( 'id',           $patron->userid );
    $session->param( 'cardnumber',   $patron->cardnumber );
    $session->param( 'firstname',    $patron->firstname );
    $session->param( 'surname',      $patron->surname );
    $session->param( 'branch',       $patron->branchcode );
    $session->param( 'branchname',   $patron->library->branchname );
    $session->param( 'flags',        $patron->flags );
    $session->param( 'emailaddress', $patron->email );
    $session->param( 'ip',           $session->remote_addr() );
    $session->param( 'lasttime',     time() );
    $session->param( 'interface',    $interface );

    return $session;
}

# FIXME no_set_userenv may be replaced with force_branchcode_for_userenv
# (or something similar)
# Currently it's only passed from C4::SIP::ILS::Patron::check_password, but
# not having a userenv defined could cause a crash.
sub checkpw {
    my ( $userid, $password, $query, $type, $no_set_userenv ) = @_;
    $type = 'opac' unless $type;

    # Get shibboleth login attribute
    my $shib       = C4::Context->preference('ShibbolethAuthentication') && shib_ok();
    my $shib_login = $shib ? get_login_shib() : undef;

    my $anonymous_patron = C4::Context->preference('AnonymousPatron');

    my @return;
    my $check_internal_as_fallback = 0;
    my $passwd_ok                  = 0;
    my $patron;

    # Note: checkpw_* routines returns:
    # 1 if auth is ok
    # 0 if auth is nok
    # -1 if user bind failed (LDAP only)
    $ldap = C4::Context->config('useldapserver') || 0;
    if ( $ldap && defined($password) ) {
        my ( $retval, $retcard, $retuserid );
        require C4::Auth_with_ldap;
        import C4::Auth_with_ldap qw(checkpw_ldap);

        ( $retval, $retcard, $retuserid, $patron ) = C4::Auth_with_ldap::checkpw_ldap(@_);    # EXTERNAL AUTH
        if ( $retval == 1 ) {
            @return    = ( $retval, $retcard, $retuserid, $patron );
            $passwd_ok = 1;
        }
        $check_internal_as_fallback = 1 if $retval == 0;

    } elsif ( $cas && $query && $query->param('ticket') ) {

        # In case of a CAS authentication, we use the ticket instead of the password
        my $ticket = $query->param('ticket');
        $query->delete('ticket');    # remove ticket to come back to original URL
        my ( $retval, $retcard, $retuserid, $cas_ticket );
        ( $retval, $retcard, $retuserid, $cas_ticket, $patron ) = checkpw_cas( $ticket, $query, $type ); # EXTERNAL AUTH
        if ($retval) {
            @return = ( $retval, $retcard, $retuserid, $patron, $cas_ticket );
        } else {
            @return = (0);
        }
        $passwd_ok = $retval;
    }

    # If we are in a shibboleth session (shibboleth is enabled, and a shibboleth match attribute is present)
    # Check for password to asertain whether we want to be testing against shibboleth or another method this
    # time around.
    elsif ( $shib && $shib_login && !$password ) {

        # In case of a Shibboleth authentication, we expect a shibboleth user attribute
        # (defined under shibboleth mapping in koha-conf.xml) to contain the login of the
        # shibboleth-authenticated user

        # Then, we check if it matches a valid koha user
        if ($shib_login) {
            my ( $retval, $retcard, $retuserid );
            ( $retval, $retcard, $retuserid, $patron ) =
                C4::Auth_with_shibboleth::checkpw_shib($shib_login);    # EXTERNAL AUTH
            if ($retval) {
                @return = ( $retval, $retcard, $retuserid, $patron );
            }
            $passwd_ok = $retval;
        }
    } else {
        $check_internal_as_fallback = 1;
    }

    if ($check_internal_as_fallback) {

        # INTERNAL AUTH
        @return    = checkpw_internal( $userid, $password, $no_set_userenv );
        $passwd_ok = $return[0];
        $patron    = $passwd_ok ? $return[3] : undef;
    }

    if ( defined $userid && !$patron ) {
        $patron = Koha::Patrons->find( { userid     => $userid } );
        $patron = Koha::Patrons->find( { cardnumber => $userid } ) unless $patron;
        push @return, $patron if $check_internal_as_fallback;    # We pass back the patron if authentication fails
    }

    if ($patron) {
        if ( $patron->account_locked ) {
            @return = ();
        } elsif ($passwd_ok) {
            $patron->update( { login_attempts => 0 } );
            if ( defined($anonymous_patron) && ( $patron->borrowernumber eq $anonymous_patron ) ) {
                @return = ( -3, $patron );
            } elsif ( $patron->password_expired ) {
                @return = ( -2, $patron );
            }
        } else {
            $patron->update( { login_attempts => $patron->login_attempts + 1 } );
        }
    }

    # Optionally log success or failure
    if ( $patron && $passwd_ok && C4::Context->preference('AuthSuccessLog') ) {
        logaction( 'AUTH', 'SUCCESS', $patron->id, "Valid password for $userid", $type );
    } elsif ( !$passwd_ok && C4::Context->preference('AuthFailureLog') ) {
        logaction( 'AUTH', 'FAILURE', $patron ? $patron->id : 0, "Wrong password for $userid", $type );
    }

    return @return;
}

sub checkpw_internal {
    my ( $userid, $password, $no_set_userenv ) = @_;

    $password = Encode::encode( 'UTF-8', $password )
        if Encode::is_utf8($password);

    my $patron = Koha::Patrons->find( { userid => $userid } );
    if ($patron) {
        if ( checkpw_hash( $password, $patron->password ) ) {
            my $borrowernumber = $patron->borrowernumber;
            C4::Context->set_userenv(
                "$borrowernumber",  $patron->userid,  $patron->cardnumber,
                $patron->firstname, $patron->surname, $patron->branchcode, $patron->library->branchname, $patron->flags
            ) unless $no_set_userenv;
            return 1, $patron->cardnumber, $patron->userid, $patron;
        }
    }
    $patron = Koha::Patrons->find( { cardnumber => $userid } );
    if ($patron) {
        if ( checkpw_hash( $password, $patron->password ) ) {
            my $borrowernumber = $patron->borrowernumber;
            C4::Context->set_userenv(
                "$borrowernumber",  $patron->userid,  $patron->cardnumber,
                $patron->firstname, $patron->surname, $patron->branchcode, $patron->library->branchname, $patron->flags
            ) unless $no_set_userenv;
            return 1, $patron->cardnumber, $patron->userid, $patron;
        }
    }
    return 0;
}

sub checkpw_hash {
    my ( $password, $stored_hash ) = @_;

    return if $stored_hash eq '!';

    # check what encryption algorithm was implemented: Bcrypt - if the hash starts with '$2' it is Bcrypt else md5
    my $hash;
    if ( substr( $stored_hash, 0, 2 ) eq '$2' ) {
        $hash = hash_password( $password, $stored_hash );
    } else {
        $hash = md5_base64($password);
    }
    return $hash eq $stored_hash;
}

=head2 getuserflags

    my $authflags = getuserflags($flags, $userid, [$dbh]);

Translates integer flags into permissions strings hash.

C<$flags> is the integer userflags value ( borrowers.userflags )
C<$userid> is the members.userid, used for building subpermissions
C<$authflags> is a hashref of permissions

=cut

sub getuserflags {
    my $flags  = shift;
    my $userid = shift;
    my $dbh    = @_ ? shift : C4::Context->dbh;
    my $userflags;
    {
        # I don't want to do this, but if someone logs in as the database
        # user, it would be preferable not to spam them to death with
        # numeric warnings. So, we make $flags numeric.
        no warnings 'numeric';
        $flags += 0;
    }
    my $sth = $dbh->prepare("SELECT bit, flag, defaulton FROM userflags");
    $sth->execute;

    while ( my ( $bit, $flag, $defaulton ) = $sth->fetchrow ) {
        if ( ( $flags & ( 2**$bit ) ) || $defaulton ) {
            $userflags->{$flag} = 1;
        } else {
            $userflags->{$flag} = 0;
        }
    }

    # get subpermissions and merge with top-level permissions
    my $user_subperms = get_user_subpermissions($userid);
    foreach my $module ( keys %$user_subperms ) {
        next if $userflags->{$module} == 1;    # user already has permission for everything in this module
        $userflags->{$module} = $user_subperms->{$module};
    }

    return $userflags;
}

=head2 get_user_subpermissions

  $user_perm_hashref = get_user_subpermissions($userid);

Given the userid (note, not the borrowernumber) of a staff user,
return a hashref of hashrefs of the specific subpermissions
accorded to the user.  An example return is

 {
    tools => {
        export_catalog => 1,
        import_patrons => 1,
    }
 }

The top-level hash-key is a module or function code from
userflags.flag, while the second-level key is a code
from permissions.

The results of this function do not give a complete picture
of the functions that a staff user can access; it is also
necessary to check borrowers.flags.

=cut

sub get_user_subpermissions {
    my $userid = shift;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "SELECT flag, user_permissions.code
                             FROM user_permissions
                             JOIN permissions USING (module_bit, code)
                             JOIN userflags ON (module_bit = bit)
                             JOIN borrowers USING (borrowernumber)
                             WHERE userid = ?"
    );
    $sth->execute($userid);

    my $user_perms = {};
    while ( my $perm = $sth->fetchrow_hashref ) {
        $user_perms->{ $perm->{'flag'} }->{ $perm->{'code'} } = 1;
    }
    return $user_perms;
}

=head2 get_all_subpermissions

  my $perm_hashref = get_all_subpermissions();

Returns a hashref of hashrefs defining all specific
permissions currently defined.  The return value
has the same structure as that of C<get_user_subpermissions>,
except that the innermost hash value is the description
of the subpermission.

=cut

sub get_all_subpermissions {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "SELECT flag, code
                             FROM permissions
                             JOIN userflags ON (module_bit = bit)"
    );
    $sth->execute();

    my $all_perms = {};
    while ( my $perm = $sth->fetchrow_hashref ) {
        $all_perms->{ $perm->{'flag'} }->{ $perm->{'code'} } = 1;
    }
    return $all_perms;
}

=head2 get_cataloguing_page_permissions

    my $required_permissions = get_cataloguing_page_permissions();

Returns the required permissions to access the main cataloguing page. Useful for building
the global I<can_see_cataloguing_module> template variable, and also for reusing in
I<cataloging-home.pl>.

=cut

sub get_cataloguing_page_permissions {

    my @cataloguing_tools_subperms = qw(
        inventory
        items_batchdel
        items_batchmod
        items_batchmod
        label_creator
        manage_staged_marc
        marc_modification_templates
        records_batchdel
        records_batchmod
        stage_marc_import
        upload_cover_images
    );

    return [
        { editcatalogue => '*' }, { tools => \@cataloguing_tools_subperms },
        C4::Context->preference('StockRotation') ? { stockrotation => 'manage_rotas' } : ()
    ];
}

=head2 haspermission

  $flagsrequired = '*';                                 # Any permission at all
  $flagsrequired = 'a_flag';                            # a_flag must be satisfied (all subpermissions)
  $flagsrequired = [ 'a_flag', 'b_flag' ];              # a_flag OR b_flag must be satisfied
  $flagsrequired = { 'a_flag => 1, 'b_flag' => 1 };     # a_flag AND b_flag must be satisfied
  $flagsrequired = { 'a_flag' => 'sub_a' };             # sub_a of a_flag must be satisfied
  $flagsrequired = { 'a_flag' => [ 'sub_a, 'sub_b' ] }; # sub_a OR sub_b of a_flag must be satisfied
  $flagsrequired = { 'a_flag' => { 'sub_a' => 1, 'sub_b' => 1 } };    # sub_a AND sub_b of a_flag must be satisfied

  $flags = ($userid, $flagsrequired);

C<$userid> the userid of the member
C<$flags> is a query structure similar to that used by SQL::Abstract that
denotes the combination of flags required. It is a required parameter.

The main logic of this method is that things in arrays are OR'ed, and things
in hashes are AND'ed. The `*` character can be used, at any depth, to denote `ANY`

Returns member's flags or 0 if a permission is not met.

=cut

sub _dispatch {
    my ( $required, $flags ) = @_;

    my $ref = ref($required);
    if ( $ref eq '' ) {
        if ( $required eq '*' ) {
            return 0 unless ( $flags or ref($flags) );
        } else {
            return 0 unless ( $flags and ( !ref($flags) || $flags->{$required} ) );
        }
    } elsif ( $ref eq 'HASH' ) {
        foreach my $key ( keys %{$required} ) {
            next if $flags == 1;
            my $require = $required->{$key};
            my $rflags  = $flags->{$key};
            return 0 unless _dispatch( $require, $rflags );
        }
    } elsif ( $ref eq 'ARRAY' ) {
        my $satisfied = 0;
        foreach my $require ( @{$required} ) {
            my $rflags =
                ( ref($flags) && !ref($require) && ( $require ne '*' ) )
                ? $flags->{$require}
                : $flags;
            $satisfied++ if _dispatch( $require, $rflags );
        }
        return 0 unless $satisfied;
    } else {
        croak "Unexpected structure found: $ref";
    }

    return $flags;
}

sub haspermission {
    my ( $userid, $flagsrequired ) = @_;

    #Koha::Exceptions::WrongParameter->throw('$flagsrequired should not be undef')
    #  unless defined($flagsrequired);

    my $sth = C4::Context->dbh->prepare("SELECT flags FROM borrowers WHERE userid=?");
    $sth->execute($userid);
    my $row   = $sth->fetchrow();
    my $flags = getuserflags( $row, $userid );

    return $flags unless defined($flagsrequired);
    return $flags if $flags->{superlibrarian};
    return _dispatch( $flagsrequired, $flags );

    #FIXME - This fcn should return the failed permission so a suitable error msg can be delivered.
}

=head2 in_iprange

  $flags = ($iprange);

C<$iprange> A space separated string describing an IP range. Can include single IPs or ranges

Returns 1 if the remote address is in the provided iprange, or 0 otherwise.

=cut

sub in_iprange {
    my ($iprange)       = @_;
    my $result          = 1;
    my @allowedipranges = $iprange ? split( ' ', $iprange ) : ();
    if ( scalar @allowedipranges > 0 ) {
        my @rangelist;
        eval { @rangelist = Net::CIDR::range2cidr(@allowedipranges); };
        return 0 if $@;
        eval { $result = Net::CIDR::cidrlookup( $ENV{'REMOTE_ADDR'}, @rangelist ) }
            || Koha::Logger->get->warn( 'cidrlookup failed for ' . join( ' ', @rangelist ) );
    }
    return $result ? 1 : 0;
}

sub getborrowernumber {
    my ($userid) = @_;
    my $userenv = C4::Context->userenv;
    if ( defined($userenv) && ref($userenv) eq 'HASH' && $userenv->{number} ) {
        return $userenv->{number};
    }
    my $dbh = C4::Context->dbh;
    for my $field ( 'userid', 'cardnumber' ) {
        my $sth = $dbh->prepare("select borrowernumber from borrowers where $field=?");
        $sth->execute($userid);
        if ( $sth->rows ) {
            my ($bnumber) = $sth->fetchrow;
            return $bnumber;
        }
    }
    return 0;
}

END { }    # module clean-up code here (global destructor)
1;
__END__

=head1 SEE ALSO

CGI(3)

C4::Output(3)

Crypt::Eksblowfish::Bcrypt(3)

Digest::MD5(3)

=cut
