#!/usr/bin/perl

# Copyright 2006 SAN OUEST PROVENCE et Paul POULAIN
# Copyright 2010 BibLibre
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

# pragma
use Modern::Perl;

# external modules
use CGI qw ( -utf8 );
use List::MoreUtils qw/uniq/;

# internal modules
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::AttributeTypes;
use C4::Koha;
use C4::Log;
use C4::Letters;
use C4::Form::MessagingPreferences;
use Koha::AuthUtils;
use Koha::AuthorisedValues;
use Koha::Patron::Debarments;
use Koha::Cities;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Patron::HouseboundRole;
use Koha::Patron::HouseboundRoles;
use Koha::Token;
use Email::Valid;
use Koha::SMS::Providers;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}
	
my $input = new CGI;
($debug) or $debug = $input->param('debug') || 0;
my %data;

my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/memberentrygen.tt",
           query => $input,
           type => "intranet",
           authnotrequired => 0,
           flagsrequired => {borrowers => 'edit_borrowers'},
           debug => ($debug) ? 1 : 0,
       });

my $borrowernumber = $input->param('borrowernumber');
my $patron         = Koha::Patrons->find($borrowernumber);

if ( $borrowernumber and not $patron ) {
    output_and_exit( $input, $cookie, $template,  'unknown_patron' );
}

if ( C4::Context->preference('SMSSendDriver') eq 'Email' ) {
    my @providers = Koha::SMS::Providers->search();
    $template->param( sms_providers => \@providers );
}

my $guarantorid    = $input->param('guarantorid');
my $actionType     = $input->param('actionType') || '';
my $modify         = $input->param('modify');
my $delete         = $input->param('delete');
my $op             = $input->param('op');
my $destination    = $input->param('destination');
my $cardnumber     = $input->param('cardnumber');
my $check_member   = $input->param('check_member');
my $nodouble       = $input->param('nodouble');
my $duplicate      = $input->param('duplicate');
my $quickadd       = $input->param('quickadd');
$nodouble = 1 if ($op eq 'modify' or $op eq 'duplicate');    # FIXME hack to represent fact that if we're
                                     # modifying an existing patron, it ipso facto
                                     # isn't a duplicate.  Marking FIXME because this
                                     # script needs to be refactored.
my $nok           = $input->param('nok');
my $guarantorinfo = $input->param('guarantorinfo');
my $step          = $input->param('step') || 0;
my @errors;
my $borrower_data;
my $NoUpdateLogin;
my $userenv = C4::Context->userenv;

## Deal with debarments
$template->param(
    debarments => scalar GetDebarments( { borrowernumber => $borrowernumber } ) );
my @debarments_to_remove = $input->multi_param('remove_debarment');
foreach my $d ( @debarments_to_remove ) {
    DelDebarment( $d );
}
if ( $input->param('add_debarment') ) {

    my $expiration = $input->param('debarred_expiration');
    $expiration =
      $expiration
      ? dt_from_string($expiration)->ymd
      : undef;

    AddDebarment(
        {
            borrowernumber => $borrowernumber,
            type           => 'MANUAL',
            comment        => scalar $input->param('debarred_comment'),
            expiration     => $expiration,
        }
    );
}

$template->param("uppercasesurnames" => C4::Context->preference('uppercasesurnames'));

# function to designate mandatory fields (visually with css)
my $check_BorrowerMandatoryField=C4::Context->preference("BorrowerMandatoryField");
my @field_check=split(/\|/,$check_BorrowerMandatoryField);
foreach (@field_check) {
	$template->param( "mandatory$_" => 1);    
}
# function to designate unwanted fields
my $check_BorrowerUnwantedField=C4::Context->preference("BorrowerUnwantedField");
@field_check=split(/\|/,$check_BorrowerUnwantedField);
foreach (@field_check) {
    next unless m/\w/o;
	$template->param( "no$_" => 1);
}
$template->param( "add" => 1 ) if ( $op eq 'add' );
$template->param( "quickadd" => 1 ) if ( $quickadd );
$template->param( "duplicate" => 1 ) if ( $op eq 'duplicate' );
$template->param( "checked" => 1 ) if ( defined($nodouble) && $nodouble eq 1 );
if ( $op eq 'modify' or $op eq 'save' or $op eq 'duplicate' ) {
    my $logged_in_user = Koha::Patrons->find( $loggedinuser ) or die "Not logged in";
    output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

    $borrower_data = $patron->unblessed;
    $borrower_data->{category_type} = $patron->category->category_type;
}

my $categorycode  = $input->param('categorycode') || $borrower_data->{'categorycode'};
my $category_type = $input->param('category_type') || '';
unless ($category_type or !($categorycode)){
    my $borrowercategory = Koha::Patron::Categories->find($categorycode);
    $category_type    = $borrowercategory->category_type;
    my $category_name = $borrowercategory->description;
    $template->param("categoryname"=>$category_name);
}
$category_type="A" unless $category_type; # FIXME we should display a error message instead of a 500 error !

# if a add or modify is requested => check validity of data.
%data = %$borrower_data if ($borrower_data);

# initialize %newdata
my %newdata;                                                                             # comes from $input->param()
if ( $op eq 'insert' || $op eq 'modify' || $op eq 'save' || $op eq 'duplicate' ) {
    my @names = ( $borrower_data && $op ne 'save' ) ? keys %$borrower_data : $input->param();
    foreach my $key (@names) {
        if (defined $input->param($key)) {
            $newdata{$key} = $input->param($key);
        }
    }

    foreach (qw(dateenrolled dateexpiry dateofbirth)) {
        next unless exists $newdata{$_};
        my $userdate = $newdata{$_} or next;

        my $formatteddate = eval { output_pref({ dt => dt_from_string( $userdate ), dateformat => 'iso', dateonly => 1 } ); };
        if ( $formatteddate ) {
            $newdata{$_} = $formatteddate;
        } else {
            ($userdate eq '0000-00-00') and warn "Data error: $_ is '0000-00-00'";
            $template->param( "ERROR_$_" => 1 );
            push(@errors,"ERROR_$_");
        }
    }
  # check permission to modify login info.
    if (ref($borrower_data) && ($borrower_data->{'category_type'} eq 'S') && ! (C4::Auth::haspermission($userenv->{'id'},{'staffaccess'=>1})) )  {
        $NoUpdateLogin = 1;
    }
}

# remove keys from %newdata that is not part of patron's attributes
{
    my @keys_to_delete = (
        qr/^BorrowerMandatoryField$/,
        qr/^category_type$/,
        qr/^check_member$/,
        qr/^destination$/,
        qr/^nodouble$/,
        qr/^op$/,
        qr/^save$/,
        qr/^updtype$/,
        qr/^SMSnumber$/,
        qr/^setting_extended_patron_attributes$/,
        qr/^setting_messaging_prefs$/,
        qr/^digest$/,
        qr/^modify$/,
        qr/^step$/,
        qr/^\d+$/,
        qr/^\d+-DAYS/,
        qr/^patron_attr_/,
        qr/^csrf_token$/,
        qr/^add_debarment$/, qr/^debarred_expiration$/, # We already dealt with debarments previously
        qr/^housebound_chooser$/, qr/^housebound_deliverer$/,
        qr/^select_city$/,
    );
    for my $regexp (@keys_to_delete) {
        for (keys %newdata) {
            delete($newdata{$_}) if /$regexp/;
        }
    }
}

# Test uniqueness of surname, firstname and dateofbirth
if ( ( $op eq 'insert' ) and !$nodouble ) {
    my $conditions;
    $conditions->{surname} = $newdata{surname} if $newdata{surname};
    if ( $category_type ne 'I' ) {
        $conditions->{firstname} = $newdata{firstname} if $newdata{firstname};
        $conditions->{dateofbirth} = $newdata{dateofbirth} if $newdata{dateofbirth};
    }
    $nodouble = 1;
    my $patrons = Koha::Patrons->search($conditions); # FIXME Should be search_limited?
    if ( $patrons->count > 0) {
        $nodouble = 0;
        $check_member = $patrons->next->borrowernumber;
    }
}

  #recover all data from guarantor address phone ,fax... 
if ( $guarantorid ) {
    if (my $guarantor = Koha::Patrons->find( $guarantorid )) {
        my $guarantordata = $guarantor->unblessed;
        $category_type = $guarantordata->{categorycode} eq 'I' ? 'P' : 'C';
        $guarantorinfo=$guarantordata->{'surname'}." , ".$guarantordata->{'firstname'};
        $newdata{'contactfirstname'}= $guarantordata->{'firstname'};
        $newdata{'contactname'}     = $guarantordata->{'surname'};
        $newdata{'contacttitle'}    = $guarantordata->{'title'};
        if ( $op eq 'add' ) {
	        foreach (qw(streetnumber address streettype address2
                        zipcode country city state phone phonepro mobile fax email emailpro branchcode
                        B_streetnumber B_streettype B_address B_address2
                        B_city B_state B_zipcode B_country B_email B_phone)) {
		        $newdata{$_} = $guarantordata->{$_};
	        }
        }
    }
}

###############test to take the right zipcode, country and city name ##############
# set only if parameter was passed from the form
$newdata{'city'}    = $input->param('city')    if defined($input->param('city'));
$newdata{'zipcode'} = $input->param('zipcode') if defined($input->param('zipcode'));
$newdata{'country'} = $input->param('country') if defined($input->param('country'));

$newdata{'lang'}    = $input->param('lang')    if defined($input->param('lang'));

# builds default userid
# userid input text may be empty or missing because of syspref BorrowerUnwantedField
if ( ( defined $newdata{'userid'} && $newdata{'userid'} eq '' ) || $check_BorrowerUnwantedField =~ /userid/ && !defined $data{'userid'} ) {
    my $fake_patron = Koha::Patron->new;
    $fake_patron->userid($patron->userid) if $patron; # editing
    if ( ( defined $newdata{'firstname'} || $category_type eq 'I' ) && ( defined $newdata{'surname'} ) ) {
        # Full page edit, firstname and surname input zones are present
        $fake_patron->firstname($newdata{firstname});
        $fake_patron->surname($newdata{surname});
        $fake_patron->generate_userid;
        $newdata{'userid'} = $fake_patron->userid;
    }
    elsif ( ( defined $data{'firstname'} || $category_type eq 'I' ) && ( defined $data{'surname'} ) ) {
        # Partial page edit (access through "Details"/"Library details" tab), firstname and surname input zones are not used
        # Still, if the userid field is erased, we can create a new userid with available firstname and surname
        # FIXME clean thiscode newdata vs data is very confusing
        $fake_patron->firstname($data{firstname});
        $fake_patron->surname($data{surname});
        $fake_patron->generate_userid;
        $newdata{'userid'} = $fake_patron->userid;
    }
    else {
        $newdata{'userid'} = $data{'userid'};
    }
}
  
$debug and warn join "\t", map {"$_: $newdata{$_}"} qw(dateofbirth dateenrolled dateexpiry);
my $extended_patron_attributes = ();
if ($op eq 'save' || $op eq 'insert'){

    die "Wrong CSRF token"
        unless Koha::Token->new->check_csrf({
            session_id => scalar $input->cookie('CGISESSID'),
            token  => scalar $input->param('csrf_token'),
        });

    # If the cardnumber is blank, treat it as null.
    $newdata{'cardnumber'} = undef if $newdata{'cardnumber'} =~ /^\s*$/;

    if (my $error_code = checkcardnumber($newdata{cardnumber},$newdata{borrowernumber})){
        push @errors, $error_code == 1
            ? 'ERROR_cardnumber_already_exists'
            : $error_code == 2
                ? 'ERROR_cardnumber_length'
                : ()
    }

    my $dateofbirth;
    if ($op eq 'save' && $step == 3) {
        $dateofbirth = $patron->dateofbirth;
    }
    else {
        $dateofbirth = $newdata{dateofbirth};
    }

    if ( $dateofbirth ) {
        my $patron = Koha::Patron->new({ dateofbirth => $dateofbirth });
        my $age = $patron->get_age;
        my $borrowercategory = Koha::Patron::Categories->find($categorycode);
        my ($low,$high) = ($borrowercategory->dateofbirthrequired, $borrowercategory->upperagelimit);
        if (($high && ($age > $high)) or ($age < $low)) {
            push @errors, 'ERROR_age_limitations';
            $template->param( age_low => $low);
            $template->param( age_high => $high);
        }
    }
  
    if($newdata{surname} && C4::Context->preference('uppercasesurnames')) {
        $newdata{'surname'} = uc($newdata{'surname'});
    }

  if (C4::Context->preference("IndependentBranches")) {
    unless ( C4::Context->IsSuperLibrarian() ){
      $debug and print STDERR "  $newdata{'branchcode'} : ".$userenv->{flags}.":".$userenv->{branch};
      unless (!$newdata{'branchcode'} || $userenv->{branch} eq $newdata{'branchcode'}){
        push @errors, "ERROR_branch";
      }
    }
  }
  # Check if the 'userid' is unique. 'userid' might not always be present in
  # the edited values list when editing certain sub-forms. Get it straight
  # from the DB if absent.
  my $userid = $newdata{ userid } // $borrower_data->{ userid };
  my $p = $borrowernumber ? Koha::Patrons->find( $borrowernumber ) : Koha::Patron->new;
  $p->userid( $userid );
  unless ( $p->has_valid_userid ) {
    push @errors, "ERROR_login_exist";
  }

  my $password = $input->param('password');
  my $password2 = $input->param('password2');
  push @errors, "ERROR_password_mismatch" if ( $password ne $password2 );

  if ( $password and $password ne '****' ) {
      my ( $is_valid, $error ) = Koha::AuthUtils::is_password_valid( $password );
      unless ( $is_valid ) {
          push @errors, 'ERROR_password_too_short' if $error eq 'too_short';
          push @errors, 'ERROR_password_too_weak' if $error eq 'too_weak';
          push @errors, 'ERROR_password_has_whitespaces' if $error eq 'has_whitespaces';
      }
  }

  # Validate emails
  my $emailprimary = $input->param('email');
  my $emailsecondary = $input->param('emailpro');
  my $emailalt = $input->param('B_email');

  if ($emailprimary) {
      push (@errors, "ERROR_bad_email") if (!Email::Valid->address($emailprimary));
  }
  if ($emailsecondary) {
      push (@errors, "ERROR_bad_email_secondary") if (!Email::Valid->address($emailsecondary));
  }
  if ($emailalt) {
      push (@errors, "ERROR_bad_email_alternative") if (!Email::Valid->address($emailalt));
  }

  if (C4::Context->preference('ExtendedPatronAttributes')) {
    $extended_patron_attributes = parse_extended_patron_attributes($input);
    foreach my $attr (@$extended_patron_attributes) {
        unless (C4::Members::Attributes::CheckUniqueness($attr->{code}, $attr->{value}, $borrowernumber)) {
            my $attr_info = C4::Members::AttributeTypes->fetch($attr->{code});
            push @errors, "ERROR_extended_unique_id_failed";
            $template->param(
                ERROR_extended_unique_id_failed_code => $attr->{code},
                ERROR_extended_unique_id_failed_value => $attr->{value},
                ERROR_extended_unique_id_failed_description => $attr_info->description()
            );
        }
    }
  }
}

if ( ($op eq 'modify' || $op eq 'insert' || $op eq 'save'|| $op eq 'duplicate') and ($step == 0 or $step == 3 )){
    unless ($newdata{'dateexpiry'}){
        my $patron_category = Koha::Patron::Categories->find( $newdata{categorycode} );
        $newdata{'dateexpiry'} = $patron_category->get_expiry_date( $newdata{dateenrolled} ) if $patron_category;
    }
}

# BZ 14683: Do not mixup mobile [read: other phone] with smsalertnumber
my $sms = $input->param('SMSnumber');
if ( defined $sms ) {
    $newdata{smsalertnumber} = $sms;
}

###  Error checks should happen before this line.
$nok = $nok || scalar(@errors);
if ((!$nok) and $nodouble and ($op eq 'insert' or $op eq 'save')){
	$debug and warn "$op dates: " . join "\t", map {"$_: $newdata{$_}"} qw(dateofbirth dateenrolled dateexpiry);
	if ($op eq 'insert'){
		# we know it's not a duplicate borrowernumber or there would already be an error
        delete $newdata{password2};
        my $patron = eval { Koha::Patron->new(\%newdata)->store };
        if ( $@ ) {
            # FIXME Urgent error handling here, we cannot fail without relevant feedback
            # Lot of code will need to be removed from this script to handle exceptions raised by Koha::Patron->store
            warn "Patron creation failed! - $@"; # Maybe we must die instead of just warn
        } else {
            $borrowernumber = $patron->borrowernumber;
        }

        # If 'AutoEmailOpacUser' syspref is on, email user their account details from the 'notice' that matches the user's branchcode.
        if ( C4::Context->preference("AutoEmailOpacUser") == 1 && $newdata{'userid'}  && $newdata{'password'}) {
            #look for defined primary email address, if blank - attempt to use borr.email and borr.emailpro instead
            my $emailaddr;
            if  (C4::Context->preference("AutoEmailPrimaryAddress") ne 'OFF'  && 
                $newdata{C4::Context->preference("AutoEmailPrimaryAddress")} =~  /\w\@\w/ ) {
                $emailaddr =   $newdata{C4::Context->preference("AutoEmailPrimaryAddress")} 
            } 
            elsif ($newdata{email} =~ /\w\@\w/) {
                $emailaddr = $newdata{email} 
            }
            elsif ($newdata{emailpro} =~ /\w\@\w/) {
                $emailaddr = $newdata{emailpro} 
            }
            elsif ($newdata{B_email} =~ /\w\@\w/) {
                $emailaddr = $newdata{B_email} 
            }
            # if we manage to find a valid email address, send notice 
            if ($emailaddr) {
                $newdata{emailaddr} = $emailaddr;
                my $err;
                eval {
                    $err = SendAlerts ( 'members', \%newdata, "ACCTDETAILS" );
                };
                if ( $@ ) {
                    $template->param(error_alert => $@);
                } elsif ( ref($err) eq "HASH" && defined $err->{error} and $err->{error} eq "no_email" ) {
                    $template->{VARS}->{'error_alert'} = "no_email";
                } else {
                    $template->{VARS}->{'info_alert'} = 1;
                }
            }
        }

        if (C4::Context->preference('ExtendedPatronAttributes') and $input->param('setting_extended_patron_attributes')) {
            C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $extended_patron_attributes);
        }
        if (C4::Context->preference('EnhancedMessagingPreferences') and $input->param('setting_messaging_prefs')) {
            C4::Form::MessagingPreferences::handle_form_action($input, { borrowernumber => $borrowernumber }, $template, 1, $newdata{'categorycode'});
        }

        # Create HouseboundRole if necessary.
        # Borrower did not exist, so HouseboundRole *cannot* yet exist.
        my ( $hsbnd_chooser, $hsbnd_deliverer ) = ( 0, 0 );
        $hsbnd_chooser = 1 if $input->param('housebound_chooser');
        $hsbnd_deliverer = 1 if $input->param('housebound_deliverer');
        # Only create a HouseboundRole if patron has a role.
        if ( $hsbnd_chooser || $hsbnd_deliverer ) {
            Koha::Patron::HouseboundRole->new({
                borrowernumber_id    => $borrowernumber,
                housebound_chooser   => $hsbnd_chooser,
                housebound_deliverer => $hsbnd_deliverer,
            })->store;
        }

    } elsif ($op eq 'save') {

        # Update or create our HouseboundRole if necessary.
        my $housebound_role = Koha::Patron::HouseboundRoles->find($borrowernumber);
        my ( $hsbnd_chooser, $hsbnd_deliverer ) = ( 0, 0 );
        $hsbnd_chooser = 1 if $input->param('housebound_chooser');
        $hsbnd_deliverer = 1 if $input->param('housebound_deliverer');
        if ( $housebound_role ) {
            if ( $hsbnd_chooser || $hsbnd_deliverer ) {
                # Update our HouseboundRole.
                $housebound_role
                    ->housebound_chooser($hsbnd_chooser)
                    ->housebound_deliverer($hsbnd_deliverer)
                    ->store;
            } else {
                $housebound_role->delete; # No longer needed.
            }
        } else {
            # Only create a HouseboundRole if patron has a role.
            if ( $hsbnd_chooser || $hsbnd_deliverer ) {
                $housebound_role = Koha::Patron::HouseboundRole->new({
                    borrowernumber_id    => $borrowernumber,
                    housebound_chooser   => $hsbnd_chooser,
                    housebound_deliverer => $hsbnd_deliverer,
                })->store;
            }
        }

        if ($NoUpdateLogin) {
            delete $newdata{'password'};
            delete $newdata{'userid'};
        }

        my $patron = Koha::Patrons->find( $borrowernumber );
        $newdata{debarredcomment} = $newdata{debarred_comment};
        delete $newdata{debarred_comment};
        delete $newdata{password2};
        $patron->set(\%newdata)->store if scalar(keys %newdata) > 1; # bug 4508 - avoid crash if we're not
                                                                # updating any columns in the borrowers table,
                                                                # which can happen if we're only editing the
                                                                # patron attributes or messaging preferences sections

        $patron->update_password($newdata{userid}, $newdata{password});

        if (C4::Context->preference('ExtendedPatronAttributes') and $input->param('setting_extended_patron_attributes')) {
            C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $extended_patron_attributes);
        }
        if (C4::Context->preference('EnhancedMessagingPreferences') and $input->param('setting_messaging_prefs')) {
            C4::Form::MessagingPreferences::handle_form_action($input, { borrowernumber => $borrowernumber }, $template);
        }
	}

    if ( $destination eq 'circ' and not C4::Auth::haspermission( C4::Context->userenv->{id}, { circulate => 'circulate_remaining_permissions' } ) ) {
        # If we want to redirect to circulation.pl and need to check if the logged in user has the necessary permission
        $destination = 'not_circ';
    }
    print scalar( $destination eq "circ" )
      ? $input->redirect(
        "/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrowernumber")
      : $input->redirect(
        "/cgi-bin/koha/members/moremember.pl?borrowernumber=$borrowernumber"
      );
    exit; # You can only send 1 redirect!  After that, content or other headers don't matter.
}

if ($delete){
	print $input->redirect("/cgi-bin/koha/deletemem.pl?member=$borrowernumber");
	exit;		# same as above
}

if ($nok or !$nodouble){
    $op="add" if ($op eq "insert");
    $op="modify" if ($op eq "save");
    %data=%newdata; 
    $template->param( updtype => ($op eq 'add' ?'I':'M'));	# used to check for $op eq "insert"... but we just changed $op!
    unless ($step){  
        $template->param( step_1 => 1,step_2 => 1,step_3 => 1, step_4 => 1, step_5 => 1, step_6 => 1, step_7 => 1 );
    }  
} 
if (C4::Context->preference("IndependentBranches")) {
    my $userenv = C4::Context->userenv;
    if ( !C4::Context->IsSuperLibrarian() && $data{'branchcode'} ) {
        unless ($userenv->{branch} eq $data{'branchcode'}){
            print $input->redirect("/cgi-bin/koha/members/members-home.pl");
            exit;
        }
    }
}
if ($op eq 'add'){
    $template->param( updtype => 'I', step_1=>1, step_2=>1, step_3=>1, step_4=>1, step_5 => 1, step_6 => 1, step_7 => 1);
}
if ($op eq "modify")  {
    $template->param( updtype => 'M',modify => 1 );
    $template->param( step_1=>1, step_2=>1, step_3=>1, step_4=>1, step_5 => 1, step_6 => 1, step_7 => 1) unless $step;
    if ( $step == 4 ) {
        $template->param( categorycode => $borrower_data->{'categorycode'} );
    }
}
if ( $op eq "duplicate" ) {
    $template->param( updtype => 'I' );
    $template->param( step_1 => 1, step_2 => 1, step_3 => 1, step_4 => 1, step_5 => 1, step_6 => 1, step_7 => 1 ) unless $step;
    $data{'cardnumber'} = "";
}

if(!defined($data{'sex'})){
    $template->param( none => 1);
} elsif($data{'sex'} eq 'F'){
    $template->param( female => 1);
} elsif ($data{'sex'} eq 'M'){
    $template->param(  male => 1);
} else {
    $template->param(  none => 1);
}

##Now all the data to modify a member.

my @typeloop;
my $no_categories = 1;
my $no_add;
foreach my $category_type (qw(C A S P I X)) {
    my $patron_categories = Koha::Patron::Categories->search_limited({ category_type => $category_type }, {order_by => ['categorycode']});
    $no_categories = 0 if $patron_categories->count > 0;

    my @categoryloop;
    while ( my $patron_category = $patron_categories->next ) {
        push @categoryloop,
          { 'categorycode' => $patron_category->categorycode,
            'categoryname' => $patron_category->description,
            'categorycodeselected' =>
              ( defined($categorycode) && $patron_category->categorycode eq $categorycode ),
          };
    }
    my %typehash;
    $typehash{'typename'} = $category_type;
    my $typedescription = "typename_" . $typehash{'typename'};
    $typehash{'categoryloop'} = \@categoryloop;
    push @typeloop,
      { 'typename'       => $category_type,
        $typedescription => 1,
        'categoryloop'   => \@categoryloop
      };
}

$template->param('typeloop' => \@typeloop,
        no_categories => $no_categories);
if($no_categories){ $no_add = 1; }


my $cities = Koha::Cities->search( {}, { order_by => 'city_name' } );
my $roadtypes = C4::Koha::GetAuthorisedValues( 'ROADTYPE' );
$template->param(
    roadtypes => $roadtypes,
    cities    => $cities,
);

my $default_borrowertitle = '';
unless ( $op eq 'duplicate' ) { $default_borrowertitle=$data{'title'} }

my @relationships = split /,|\|/, C4::Context->preference('borrowerRelationship');
my @relshipdata;
while (@relationships) {
  my $relship = shift @relationships || '';
  my %row = ('relationship' => $relship);
  if (defined($data{'relationship'}) and $data{'relationship'} eq $relship) {
    $row{'selected'}=' selected';
  } else {
    $row{'selected'}='';
  }
  push(@relshipdata, \%row);
}

my %flags = ( 'gonenoaddress' => ['gonenoaddress' ],
        'lost'          => ['lost']);

 
my @flagdata;
foreach (keys(%flags)) {
	my $key = $_;
	my %row =  ('key'   => $key,
		    'name'  => $flags{$key}[0]);
	if ($data{$key}) {
		$row{'yes'}=' checked';
		$row{'no'}='';
    }
	else {
		$row{'yes'}='';
		$row{'no'}=' checked';
	}
	push @flagdata,\%row;
}

# get Branch Loop
# in modify mod: userbranch value comes from borrowers table
# in add    mod: userbranch value comes from branches table (ip correspondence)

my $userbranch = '';
if (C4::Context->userenv && C4::Context->userenv->{'branch'}) {
    $userbranch = C4::Context->userenv->{'branch'};
}

if (defined ($data{'branchcode'}) and ( $op eq 'modify' || $op eq 'duplicate' || ( $op eq 'add' && $category_type eq 'C' ) )) {
    $userbranch = $data{'branchcode'};
}
$template->param( userbranch => $userbranch );

if ( Koha::Libraries->search->count < 1 ){
    $no_add = 1;
    $template->param(no_branches => 1);
}
if($no_categories){
    $no_add = 1;
    $template->param(no_categories => 1);
}
$template->param(no_add => $no_add);
# --------------------------------------------------------------------------------------------------------

$template->param( sort1 => $data{'sort1'});
$template->param( sort2 => $data{'sort2'});

if ($nok) {
    foreach my $error (@errors) {
        $template->param($error) || $template->param( $error => 1);
    }
    $template->param(nok => 1);
}
  
  #Formatting data for display    
  
if (!defined($data{'dateenrolled'}) or $data{'dateenrolled'} eq ''){
  $data{'dateenrolled'} = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
}
if ( $op eq 'duplicate' ) {
    $data{'dateenrolled'} = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
    my $patron_category = Koha::Patron::Categories->find( $data{categorycode} );
    $data{dateexpiry} = $patron_category->get_expiry_date( $data{dateenrolled} );
}
if (C4::Context->preference('uppercasesurnames')) {
    $data{'surname'} &&= uc( $data{'surname'} );
    $data{'contactname'} &&= uc( $data{'contactname'} );
}

foreach (qw(dateenrolled dateexpiry dateofbirth)) {
    if ( $data{$_} ) {
       $data{$_} = eval { output_pref({ dt => dt_from_string( $data{$_} ), dateonly => 1 } ); };  # back to syspref for display
    }
    $template->param( $_ => $data{$_});
}

if (C4::Context->preference('ExtendedPatronAttributes')) {
    $template->param(ExtendedPatronAttributes => 1);
    patron_attributes_form($template, $borrowernumber);
}

if (C4::Context->preference('EnhancedMessagingPreferences')) {
    if ($op eq 'add') {
        C4::Form::MessagingPreferences::set_form_values({ categorycode => $categorycode }, $template);
    } else {
        C4::Form::MessagingPreferences::set_form_values({ borrowernumber => $borrowernumber }, $template);
    }
    $template->param(SMSSendDriver => C4::Context->preference("SMSSendDriver"));
    $template->param(SMSnumber     => $data{'smsalertnumber'} );
    $template->param(TalkingTechItivaPhone => C4::Context->preference("TalkingTechItivaPhoneNotification"));
}

$template->param( "showguarantor"  => ($category_type=~/A|I|S|X/) ? 0 : 1); # associate with step to know where you are
$debug and warn "memberentry step: $step";
$template->param(%data);
$template->param( "step_$step"  => 1) if $step;	# associate with step to know where u are
$template->param(  step  => $step   ) if $step;	# associate with step to know where u are

$template->param(
  BorrowerMandatoryField => C4::Context->preference("BorrowerMandatoryField"),#field to test with javascript
  category_type => $category_type,#to know the category type of the borrower
  "$category_type"  => 1,# associate with step to know where u are
  destination   => $destination,#to know wher u come from and wher u must go in redirect
  check_member    => $check_member,#to know if the borrower already exist(=>1) or not (=>0) 
  "op$op"   => 1);

$guarantorid = $borrower_data->{'guarantorid'} || $guarantorid;
my $guarantor = $guarantorid ? Koha::Patrons->find( $guarantorid ) : undef;
$template->param(
  patron => $patron ? $patron : \%newdata, # Used by address include templates now
  nodouble  => $nodouble,
  borrowernumber  => $borrowernumber, #register number
  guarantor   => $guarantor,
  guarantorid => $guarantorid,
  relshiploop => \@relshipdata,
  btitle=> $default_borrowertitle,
  guarantorinfo   => $guarantorinfo,
  flagloop  => \@flagdata,
  category_type =>$category_type,
  modify          => $modify,
  nok     => $nok,#flag to know if an error
  NoUpdateLogin =>  $NoUpdateLogin,
  );

# Generate CSRF token
$template->param( csrf_token =>
      Koha::Token->new->generate_csrf( { session_id => scalar $input->cookie('CGISESSID'), } ),
);

# HouseboundModule data
$template->param(
    housebound_role  => scalar Koha::Patron::HouseboundRoles->find($borrowernumber),
);

if(defined($data{'flags'})){
  $template->param(flags=>$data{'flags'});
}
if(defined($data{'contacttitle'})){
  $template->param("contacttitle_" . $data{'contacttitle'} => "SELECTED");
}


my ( $min, $max ) = C4::Members::get_cardnumber_length();
if ( defined $min ) {
    $template->param(
        minlength_cardnumber => $min,
        maxlength_cardnumber => $max
    );
}

if ( C4::Context->preference('TranslateNotices') ) {
    my $translated_languages = C4::Languages::getTranslatedLanguages( 'opac', C4::Context->preference('template') );
    $template->param( languages => $translated_languages );
}

output_html_with_http_headers $input, $cookie, $template->output;

sub  parse_extended_patron_attributes {
    my ($input) = @_;
    my @patron_attr = grep { /^patron_attr_\d+$/ } $input->multi_param();

    my @attr = ();
    my %dups = ();
    foreach my $key (@patron_attr) {
        my $value = $input->param($key);
        next unless defined($value) and $value ne '';
        my $code     = $input->param("${key}_code");
        next if exists $dups{$code}->{$value};
        $dups{$code}->{$value} = 1;
        push @attr, { code => $code, value => $value };
    }
    return \@attr;
}

sub patron_attributes_form {
    my $template = shift;
    my $borrowernumber = shift;

    my @types = C4::Members::AttributeTypes::GetAttributeTypes();
    if (scalar(@types) == 0) {
        $template->param(no_patron_attribute_types => 1);
        return;
    }
    my $attributes = C4::Members::Attributes::GetBorrowerAttributes($borrowernumber);
    my @classes = uniq( map {$_->{class}} @$attributes );
    @classes = sort @classes;

    # map patron's attributes into a more convenient structure
    my %attr_hash = ();
    foreach my $attr (@$attributes) {
        push @{ $attr_hash{$attr->{code}} }, $attr;
    }

    my @attribute_loop = ();
    my $i = 0;
    my %items_by_class;
    foreach my $type_code (map { $_->{code} } @types) {
        my $attr_type = C4::Members::AttributeTypes->fetch($type_code);
        my $entry = {
            class             => $attr_type->class(),
            code              => $attr_type->code(),
            description       => $attr_type->description(),
            repeatable        => $attr_type->repeatable(),
            category          => $attr_type->authorised_value_category(),
            category_code     => $attr_type->category_code(),
        };
        if (exists $attr_hash{$attr_type->code()}) {
            foreach my $attr (@{ $attr_hash{$attr_type->code()} }) {
                my $newentry = { %$entry };
                $newentry->{value} = $attr->{value};
                $newentry->{use_dropdown} = 0;
                if ($attr_type->authorised_value_category()) {
                    $newentry->{use_dropdown} = 1;
                    $newentry->{auth_val_loop} = GetAuthorisedValues($attr_type->authorised_value_category(), $attr->{value});
                }
                $i++;
                $newentry->{form_id} = "patron_attr_$i";
                push @{$items_by_class{$attr_type->class()}}, $newentry;
            }
        } else {
            $i++;
            my $newentry = { %$entry };
            if ($attr_type->authorised_value_category()) {
                $newentry->{use_dropdown} = 1;
                $newentry->{auth_val_loop} = GetAuthorisedValues($attr_type->authorised_value_category());
            }
            $newentry->{form_id} = "patron_attr_$i";
            push @{$items_by_class{$attr_type->class()}}, $newentry;
        }
    }
    while ( my ($class, @items) = each %items_by_class ) {
        my $av = Koha::AuthorisedValues->search({ category => 'PA_CLASS', authorised_value => $class });
        my $lib = $av->count ? $av->next->lib : $class;
        push @attribute_loop, {
            class => $class,
            items => @items,
            lib   => $lib,
        }
    }

    $template->param(patron_attributes => \@attribute_loop);

}

# Local Variables:
# tab-width: 8
# End:
