#!/usr/bin/perl
#script to set the password, and optionally a userid, for a borrower
#written 2/5/00
#by chris@katipo.co.nz
#converted to using templates 3/16/03 by mwhansen@hmc.edu

use Modern::Perl;

use C4::Auth;
use Koha::AuthUtils;
use C4::Output;
use C4::Context;
use C4::Members;
use C4::Circulation;
use CGI qw ( -utf8 );
use C4::Members::Attributes qw(GetBorrowerAttributes);
use Koha::AuthUtils;
use Koha::Token;

use Koha::Patrons;
use Koha::Patron::Categories;

my $input = new CGI;

my $theme = $input->param('theme') || "default";

# only used if allowthemeoverride is set

my ( $template, $loggedinuser, $cookie, $staffflags ) = get_template_and_user(
    {
        template_name   => "members/member-password.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 'edit_borrowers' },
        debug           => 1,
    }
);

my $member      = $input->param('member');
my $cardnumber  = $input->param('cardnumber');
my $destination = $input->param('destination');
my $newpassword  = $input->param('newpassword');
my $newpassword2 = $input->param('newpassword2');

my @errors;

my $logged_in_user = Koha::Patrons->find( $loggedinuser ) or die "Not logged in";
my $patron = Koha::Patrons->find( $member );
output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

my $category_type = $patron->category->category_type;
my $bor = $patron->unblessed;

if ( ( $member ne $loggedinuser ) && ( $category_type eq 'S' ) ) {
    push( @errors, 'NOPERMISSION' )
      unless ( $staffflags->{'superlibrarian'} || $staffflags->{'staffaccess'} );

    # need superlibrarian for koha-conf.xml fakeuser.
}

push( @errors, 'NOMATCH' ) if ( ( $newpassword && $newpassword2 ) && ( $newpassword ne $newpassword2 ) );

if ( $newpassword and not @errors ) {
    my ( $is_valid, $error ) = Koha::AuthUtils::is_password_valid( $newpassword );
    unless ( $is_valid ) {
        push @errors, 'ERROR_password_too_short' if $error eq 'too_short';
        push @errors, 'ERROR_password_too_weak' if $error eq 'too_weak';
        push @errors, 'ERROR_password_has_whitespaces' if $error eq 'has_whitespaces';
    }
}

if ( $newpassword and not @errors) {

    output_and_exit( $input, $cookie, $template,  'wrong_csrf_token' )
        unless Koha::Token->new->check_csrf({
            session_id => scalar $input->cookie('CGISESSID'),
            token  => scalar $input->param('csrf_token'),
        });

    my $uid    = $input->param('newuserid') || $bor->{userid};
    my $password = $input->param('newpassword');
    my $dbh    = C4::Context->dbh;
    if ( Koha::Patrons->find( $member )->update_password($uid, $password) ) {
        $template->param( newpassword => $newpassword );
        if ( $destination eq 'circ' ) {
            print $input->redirect("/cgi-bin/koha/circ/circulation.pl?findborrower=$cardnumber");
        }
        else {
            print $input->redirect("/cgi-bin/koha/members/moremember.pl?borrowernumber=$member");
        }
    }
    else {
        push( @errors, 'BADUSERID' );
    }
}

if ( C4::Context->preference('ExtendedPatronAttributes') ) {
    my $attributes = GetBorrowerAttributes( $bor->{'borrowernumber'} );
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes       => $attributes
    );
}

$template->param(
    patron                     => $patron,
    destination                => $destination,
    csrf_token                 => Koha::Token->new->generate_csrf({ session_id => scalar $input->cookie('CGISESSID'), }),
);

if ( scalar(@errors) ) {
    $template->param( errormsg => 1 );
    foreach my $error (@errors) {
        $template->param($error) || $template->param( $error => 1 );
    }
}

output_html_with_http_headers $input, $cookie, $template->output;
