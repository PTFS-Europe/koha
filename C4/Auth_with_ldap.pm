package C4::Auth_with_ldap;

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
use Carp qw( croak );

use C4::Context;
use C4::Members::Messaging;
use C4::Auth qw( checkpw_internal );
use C4::Letters qw( GetPreparedLetter EnqueueLetter );
use Koha::Patrons;
use Koha::AuthUtils qw( hash_password );
use Net::LDAP;
use Net::LDAP::Filter;

our (@ISA, @EXPORT_OK);
BEGIN {
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT_OK = qw( checkpw_ldap );
}

# Redefine checkpw_ldap:
# connect to LDAP (named or anonymous)
# ~ retrieves $userid from KOHA_CONF mapping
# ~ then compares $password with userPassword 
# ~ then gets the LDAP entry
# ~ and calls the memberadd if necessary

sub ldapserver_error {
	return sprintf('No ldapserver "%s" defined in KOHA_CONF: ' . $ENV{KOHA_CONF}, shift);
}

use vars qw($mapping @ldaphosts $base $ldapname $ldappassword);
my $ldap = C4::Context->config("ldapserver") or die 'No "ldapserver" in server hash from KOHA_CONF: ' . $ENV{KOHA_CONF};
# since Bug 28278 we need to skip id in <ldapserver id="ldapserver"> which generates additional hash level
if ( exists $ldap->{ldapserver} ) {
    $ldap = $ldap->{ldapserver}         or die ldapserver_error('id="ldapserver"');
}
my $prefhost  = $ldap->{hostname}	or die ldapserver_error('hostname');
my $base      = $ldap->{base}		or die ldapserver_error('base');
$ldapname     = $ldap->{user}		;
$ldappassword = $ldap->{pass}		;
our %mapping  = %{$ldap->{mapping}}; # FIXME dpavlin -- don't die because of || (); from 6eaf8511c70eb82d797c941ef528f4310a15e9f9
my @mapkeys = keys %mapping;
#warn "Got ", scalar(@mapkeys), " ldap mapkeys (  total  ): ", join ' ', @mapkeys, "\n";
@mapkeys = grep {defined $mapping{$_}->{is}} @mapkeys;
#warn "Got ", scalar(@mapkeys), " ldap mapkeys (populated): ", join ' ', @mapkeys, "\n";

my %categorycode_conversions;
my $default_categorycode;
if(defined $ldap->{categorycode_mapping}) {
    $default_categorycode = $ldap->{categorycode_mapping}->{default};
    foreach my $cat (@{$ldap->{categorycode_mapping}->{categorycode}}) {
        $categorycode_conversions{$cat->{value}} = $cat->{content};
    }
}

my %config = (
    anonymous => defined ($ldap->{anonymous_bind}) ? $ldap->{anonymous_bind} : 1,
    replicate => defined($ldap->{replicate}) ? $ldap->{replicate} : 1,  #    add from LDAP to Koha database for new user
    welcome   => defined($ldap->{welcome}) ? $ldap->{welcome} : 0,  #    send welcome notice when patron is added via replicate
    update    => defined($ldap->{update}) ? $ldap->{update} : 1,  # update from LDAP to Koha database for existing user
);

sub description {
	my $result = shift or return;
	return "LDAP error #" . $result->code
			. ": " . $result->error_name . "\n"
			. "# " . $result->error_text . "\n";
}

sub search_method {
    my $db     = shift or return;
    my $userid = shift or return;
	my $uid_field = $mapping{userid}->{is} or die ldapserver_error("mapping for 'userid'");
	my $filter = Net::LDAP::Filter->new("$uid_field=$userid") or die "Failed to create new Net::LDAP::Filter";
	my $search = $db->search(
		  base => $base,
	 	filter => $filter,
		# attrs => ['*'],
    );
    die "LDAP search failed to return object : " . $search->error if $search->code;

	my $count = $search->count;
	if ($search->code > 0) {
		warn sprintf("LDAP Auth rejected : %s gets %d hits\n", $filter->as_string, $count) . description($search);
		return 0;
	}
    if ($count == 0) {
        warn sprintf("LDAP Auth rejected : search with filter '%s' returns no hit\n", $filter->as_string);
        return 0;
    }
    return $search;
}

sub checkpw_ldap {
    my ($dbh, $userid, $password) = @_;
    my @hosts = split(',', $prefhost);
    my $db = Net::LDAP->new(\@hosts);
    unless ( $db ) {
        warn "LDAP connexion failed";
        return 0;
    }

    my $userldapentry;

    # first, LDAP authentication
    if ( $ldap->{auth_by_bind} ) {
        my $principal_name;
        if ( $config{anonymous} ) {

            # Perform an anonymous bind
            my $res = $db->bind;
            if ( $res->code ) {
                warn "Anonymous LDAP bind failed: " . description($res);
                return 0;
            }

            # Perform a LDAP search for the given username
            my $search = search_method( $db, $userid )
              or return 0;    # warnings are in the sub
            $userldapentry = $search->shift_entry;
            $principal_name = $userldapentry->dn;
        }
        else {
            $principal_name = $ldap->{principal_name};
            if ( $principal_name and $principal_name =~ /\%/ ) {
                $principal_name = sprintf( $principal_name, $userid );
            }
            else {
                $principal_name = $userid;
            }
        }

        # Perform a LDAP bind for the given username using the matched DN
        my $res = $db->bind( $principal_name, password => $password );
        if ( $res->code ) {
            if ( $config{anonymous} ) {
                # With anonymous_bind approach we can be sure we have found the correct user
                # and that any 'code' response indicates a 'bad' user (be that blocked, banned
                # or password changed). We should not fall back to local accounts in this case.
                warn "LDAP bind failed as kohauser $userid: " . description($res);
                return -1;
            } else {
                # Without a anonymous_bind, we cannot be sure we are looking at a valid ldap user
                # at all, and thus we should fall back to local logins to restore previous behaviour
                # see bug 12831
                warn "LDAP bind failed as kohauser $userid: " . description($res);
                return 0;
            }
        }
        if ( !defined($userldapentry)
            && ( $config{update} or $config{replicate} ) )
        {
            my $search = search_method( $db, $userid ) or return 0;
            $userldapentry = $search->shift_entry;
        }
    } else {
        my $res = ($config{anonymous}) ? $db->bind : $db->bind($ldapname, password=>$ldappassword);
		if ($res->code) {		# connection refused
			warn "LDAP bind failed as ldapuser " . ($ldapname || '[ANONYMOUS]') . ": " . description($res);
			return 0;
		}
        my $search = search_method($db, $userid) or return 0;   # warnings are in the sub
        # Handle multiple branches. Same login exists several times in different branches.
        my $bind_ok = 0;
        while (my $entry = $search->shift_entry) {
            my $user_ldap_bind_ret = $db->bind($entry->dn, password => $password);
            unless ($user_ldap_bind_ret->code) {
                $userldapentry = $entry;
                $bind_ok = 1;
                last;
            }
        }

        unless ($bind_ok) {
            warn "LDAP Auth rejected : invalid password for user '$userid'.";
            return -1;
        }


    }

    # To get here, LDAP has accepted our user's login attempt.
    # But we still have work to do.  See perldoc below for detailed breakdown.

    my (%borrower);
	my ($borrowernumber,$cardnumber,$local_userid,$savedpw) = exists_local($userid);

    if (( $borrowernumber and $config{update}   ) or
        (!$borrowernumber and $config{replicate})   ) {
        %borrower = ldap_entry_2_hash($userldapentry,$userid);
        #warn "checkpw_ldap received \%borrower w/ " . keys(%borrower), " keys: ", join(' ', keys %borrower), "\n";
    }

    if ($borrowernumber) {
        if ($config{update}) { # A1, B1
            my $c2 = &update_local($local_userid,$password,$borrowernumber,\%borrower) || '';
            ($cardnumber eq $c2) or warn "update_local returned cardnumber '$c2' instead of '$cardnumber'";
        } else { # C1, D1
            # maybe update just the password?
		return(1, $cardnumber, $local_userid);
        }
    } elsif ($config{replicate}) { # A2, C2
        my @columns = Koha::Patrons->columns;
        my $patron = Koha::Patron->new(
            {
                map { exists( $borrower{$_} ) ? ( $_ => $borrower{$_} ) : () } @columns
            }
        )->store;
        die "Insert of new patron failed" unless $patron;
        $borrowernumber = $patron->borrowernumber;
        C4::Members::Messaging::SetMessagingPreferencesFromDefaults( { borrowernumber => $borrowernumber, categorycode => $borrower{'categorycode'} } );

        # Send welcome email if enabled
        if ( $config{welcome} ) {
            my $emailaddr = $patron->notice_email_address;

            # if we manage to find a valid email address, send notice
            if ($emailaddr) {
                eval {
                    my $letter = GetPreparedLetter(
                        module      => 'members',
                        letter_code => 'WELCOME',
                        branchcode  => $patron->branchcode,,
                        lang        => $patron->lang || 'default',
                        tables      => {
                            'branches'  => $patron->branchcode,
                            'borrowers' => $patron->borrowernumber,
                        },
                        want_librarian => 1,
                    ) or return;

                    my $message_id = EnqueueLetter(
                        {
                            letter                 => $letter,
                            borrowernumber         => $patron->id,
                            to_address             => $emailaddr,
                            message_transport_type => 'email'
                        }
                    );
                };
            }
        }
   } else {
        return 0;   # B2, D2
    }
    if (C4::Context->preference('ExtendedPatronAttributes') && $borrowernumber && ($config{update} ||$config{replicate})) {
        my $library_id = C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef;
        my $attribute_types = Koha::Patron::Attribute::Types->search_with_library_limits({}, {}, $library_id);
        while ( my $attribute_type = $attribute_types->next ) {
            my $code = $attribute_type->code;
            unless (exists($borrower{$code}) && $borrower{$code} !~ m/^\s*$/ ) {
                next;
            }
            my $patron = Koha::Patrons->find($borrowernumber);
            if ( $patron ) { # Should not be needed, but we are in C4::Auth LDAP...
                eval {
                    my $attribute = Koha::Patron::Attribute->new({code => $code, attribute => $borrower{$code}});
                    $patron->extended_attributes([$attribute->unblessed]);
                };
                if ($@) { # FIXME Test if Koha::Exceptions::Patron::Attribute::NonRepeatable
                    warn "ERROR_extended_unique_id_failed $code $borrower{$code}";
                }
            }
        }
    }
    return(1, $cardnumber, $userid);
}

# Pass LDAP entry object and local cardnumber (userid).
# Returns borrower hash.
# Edit KOHA_CONF so $memberhash{'xxx'} fits your ldap structure.
# Ensure that mandatory fields are correctly filled!
#
sub ldap_entry_2_hash {
	my $userldapentry = shift;
	my %borrower = ( cardnumber => shift );
	my %memberhash;
	$userldapentry->exists('uid');	# This is bad, but required!  By side-effect, this initializes the attrs hash. 
    #foreach (keys %$userldapentry) {
    #    print STDERR "\n\nLDAP key: $_\t", sprintf('(%s)', ref $userldapentry->{$_}), "\n";
    #}
	my $x = $userldapentry->{attrs} or return;
	foreach (keys %$x) {
		$memberhash{$_} = join ' ', @{$x->{$_}};	
        #warn sprintf("building \$memberhash{%s} = ", $_, join(' ', @{$x->{$_}})), "\n";
	}
    #warn "Finished \%memberhash has ", scalar(keys %memberhash), " keys\n", "Referencing \%mapping with ", scalar(keys %mapping), " keys\n";
	foreach my $key (keys %mapping) {
		my  $data = $memberhash{ lc($mapping{$key}->{is}) }; # Net::LDAP returns all names in lowercase
        #warn "mapping %20s ==> %-20s (%s)\n", $key, $mapping{$key}->{is}, $data;
		unless (defined $data) { 
            $data = $mapping{$key}->{content} || undef;
		}
        $borrower{$key} = $data;
	}
	$borrower{initials} = $memberhash{initials} || 
		( substr($borrower{'firstname'},0,1)
  		. substr($borrower{ 'surname' },0,1)
  		. " ");

    # categorycode conversions
    if(defined $categorycode_conversions{$borrower{categorycode}}) {
        $borrower{categorycode} = $categorycode_conversions{$borrower{categorycode}};
    }
    elsif($default_categorycode) {
        $borrower{categorycode} = $default_categorycode;
    }

	# check if categorycode exists, if not, fallback to default from koha-conf.xml
	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare("SELECT categorycode FROM categories WHERE categorycode = ?");
	$sth->execute( uc($borrower{'categorycode'}) );
	unless ( my $row = $sth->fetchrow_hashref ) {
		my $default = $mapping{'categorycode'}->{content};
        #warn "Can't find ", $borrower{'categorycode'}, " default to: $default for ", $borrower{userid};
		$borrower{'categorycode'} = $default
	}

	return %borrower;
}

sub exists_local {
	my $arg = shift;
	my $dbh = C4::Context->dbh;
	my $select = "SELECT borrowernumber,cardnumber,userid,password FROM borrowers ";

	my $sth = $dbh->prepare("$select WHERE userid=?");	# was cardnumber=?
	$sth->execute($arg);
    #warn "Userid '$arg' exists_local? %s\n", $sth->rows;
	($sth->rows == 1) and return $sth->fetchrow;

	$sth = $dbh->prepare("$select WHERE cardnumber=?");
	$sth->execute($arg);
    #warn "Cardnumber '$arg' exists_local? %s\n", $sth->rows;
	($sth->rows == 1) and return $sth->fetchrow;
	return 0;
}

# This function performs a password update, given the userid, borrowerid,
# and digested password. It will verify that things are correct and return the
# borrowers cardnumber. The idea is that it is used to keep the local
# passwords in sync with the LDAP passwords.
#
#   $cardnum = _do_changepassword($userid, $borrowerid, $digest)
#
# Note: if the LDAP config has the update_password tag set to a false value,
# then this will not update the password, it will simply return the cardnumber.
sub _do_changepassword {
    my ($userid, $borrowerid, $password) = @_;

    if ( exists( $ldap->{update_password} ) && !$ldap->{update_password} ) {

        # We don't store the password in the database
        my $sth = C4::Context->dbh->prepare(
            'SELECT cardnumber FROM borrowers WHERE borrowernumber=?');
        $sth->execute($borrowerid);
        die "Unable to access borrowernumber "
            . "with userid=$userid, "
            . "borrowernumber=$borrowerid"
          if !$sth->rows;
        my ($cardnum) = $sth->fetchrow;
        $sth = C4::Context->dbh->prepare(
            'UPDATE borrowers SET password = null WHERE borrowernumber=?');
        $sth->execute($borrowerid);
        return $cardnum;
    }

    my $digest = hash_password($password);
    #warn "changing local password for borrowernumber=$borrowerid to '$digest'\n";
    Koha::Patrons->find($borrowerid)->set_password({ password => $password, skip_validation => 1 });

    my ($ok, $cardnum) = checkpw_internal(C4::Context->dbh, $userid, $password);
    return $cardnum if $ok;

    warn "Password mismatch after update to borrowernumber=$borrowerid";
    return;
}

sub update_local {
    my $userid     = shift or croak "No userid";
    my $password   = shift or croak "No password";
    my $borrowerid = shift or croak "No borrowerid";
    my $borrower   = shift or croak "No borrower record";

    # skip extended patron attributes in 'borrowers' attribute update
    my @keys = keys %$borrower;
    if (C4::Context->preference('ExtendedPatronAttributes')) {
        my $library_id = C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef;
        my $attribute_types = Koha::Patron::Attribute::Types->search_with_library_limits({}, {}, $library_id);
        while ( my $attribute_type = $attribute_types->next ) {
           my $code = $attribute_type->code;
           @keys = grep { $_ ne $code } @keys;
           #warn "ignoring extended patron attribute '%s' in update_local()\n", $code;
        }
    }

    my $dbh = C4::Context->dbh;
    my $query = "UPDATE  borrowers\nSET     " .
        join(',', map {"$_=?"} @keys) .
        "\nWHERE   borrowernumber=? ";
    my $sth = $dbh->prepare($query);
    #warn $query, "\n", join "\n", map {"$_ = '" . $borrower->{$_} . "'"} @keys;
    #warn "\nuserid = $userid\n";
    $sth->execute(
        ((map {$borrower->{$_}} @keys), $borrowerid)
    );

    # MODIFY PASSWORD/LOGIN if password was mapped
    _do_changepassword($userid, $borrowerid, $password) if exists( $borrower->{'password'} );
}

1;
__END__

=head1 NAME

C4::Auth - Authenticates Koha users

=head1 SYNOPSIS

  use C4::Auth_with_ldap;

=head1 LDAP Configuration

    This module is specific to LDAP authentification. It requires Net::LDAP package and one or more
	working LDAP servers.
	To use it :
	   * Modify ldapserver element in KOHA_CONF
	   * Establish field mapping in <mapping> element.

	For example, if your user records are stored according to the inetOrgPerson schema, RFC#2798,
	the username would match the "uid" field, and the password should match the "userpassword" field.

	Make sure that ALL required fields are populated by your LDAP database (and mapped in KOHA_CONF).  
	What are the required fields?  Well, in mysql you can check the database table "borrowers" like this:

	mysql> show COLUMNS from borrowers;
		+---------------------+--------------+------+-----+---------+----------------+
		| Field               | Type         | Null | Key | Default | Extra          |
		+---------------------+--------------+------+-----+---------+----------------+
		| borrowernumber      | int(11)      | NO   | PRI | NULL    | auto_increment |
		| cardnumber          | varchar(16)  | YES  | UNI | NULL    |                |
		| surname             | mediumtext   | NO   |     | NULL    |                |
		| firstname           | text         | YES  |     | NULL    |                |
		| title               | mediumtext   | YES  |     | NULL    |                |
		| othernames          | mediumtext   | YES  |     | NULL    |                |
		| initials            | text         | YES  |     | NULL    |                |
		| streetnumber        | varchar(10)  | YES  |     | NULL    |                |
		| streettype          | varchar(50)  | YES  |     | NULL    |                |
		| address             | mediumtext   | NO   |     | NULL    |                |
		| address2            | text         | YES  |     | NULL    |                |
		| city                | mediumtext   | NO   |     | NULL    |                |
		| state               | mediumtext   | YES  |     | NULL    |                |
		| zipcode             | varchar(25)  | YES  |     | NULL    |                |
		| country             | text         | YES  |     | NULL    |                |
		| email               | mediumtext   | YES  |     | NULL    |                |
		| phone               | text         | YES  |     | NULL    |                |
		| mobile              | varchar(50)  | YES  |     | NULL    |                |
		| fax                 | mediumtext   | YES  |     | NULL    |                |
		| emailpro            | text         | YES  |     | NULL    |                |
		| phonepro            | text         | YES  |     | NULL    |                |
		| B_streetnumber      | varchar(10)  | YES  |     | NULL    |                |
		| B_streettype        | varchar(50)  | YES  |     | NULL    |                |
		| B_address           | varchar(100) | YES  |     | NULL    |                |
		| B_address2          | text         | YES  |     | NULL    |                |
		| B_city              | mediumtext   | YES  |     | NULL    |                |
		| B_state             | mediumtext   | YES  |     | NULL    |                |
		| B_zipcode           | varchar(25)  | YES  |     | NULL    |                |
		| B_country           | text         | YES  |     | NULL    |                |
		| B_email             | text         | YES  |     | NULL    |                |
		| B_phone             | mediumtext   | YES  |     | NULL    |                |
		| dateofbirth         | date         | YES  |     | NULL    |                |
		| branchcode          | varchar(10)  | NO   | MUL |         |                |
		| categorycode        | varchar(10)  | NO   | MUL |         |                |
		| dateenrolled        | date         | YES  |     | NULL    |                |
		| dateexpiry          | date         | YES  |     | NULL    |                |
		| gonenoaddress       | tinyint(1)   | YES  |     | NULL    |                |
		| lost                | tinyint(1)   | YES  |     | NULL    |                |
		| debarred            | date         | YES  |     | NULL    |                |
		| debarredcomment     | varchar(255) | YES  |     | NULL    |                |
		| contactname         | mediumtext   | YES  |     | NULL    |                |
		| contactfirstname    | text         | YES  |     | NULL    |                |
		| contacttitle        | text         | YES  |     | NULL    |                |
		| borrowernotes       | mediumtext   | YES  |     | NULL    |                |
		| relationship        | varchar(100) | YES  |     | NULL    |                |
		| ethnicity           | varchar(50)  | YES  |     | NULL    |                |
		| ethnotes            | varchar(255) | YES  |     | NULL    |                |
		| sex                 | varchar(1)   | YES  |     | NULL    |                |
		| password            | varchar(30)  | YES  |     | NULL    |                |
		| flags               | int(11)      | YES  |     | NULL    |                |
		| userid              | varchar(30)  | YES  | MUL | NULL    |                |
		| opacnote            | mediumtext   | YES  |     | NULL    |                |
		| contactnote         | varchar(255) | YES  |     | NULL    |                |
		| sort1               | varchar(80)  | YES  |     | NULL    |                |
		| sort2               | varchar(80)  | YES  |     | NULL    |                |
		| altcontactfirstname | varchar(255) | YES  |     | NULL    |                |
		| altcontactsurname   | varchar(255) | YES  |     | NULL    |                |
		| altcontactaddress1  | varchar(255) | YES  |     | NULL    |                |
		| altcontactaddress2  | varchar(255) | YES  |     | NULL    |                |
		| altcontactaddress3  | varchar(255) | YES  |     | NULL    |                |
		| altcontactstate     | mediumtext   | YES  |     | NULL    |                |
		| altcontactzipcode   | varchar(50)  | YES  |     | NULL    |                |
		| altcontactcountry   | text         | YES  |     | NULL    |                |
		| altcontactphone     | varchar(50)  | YES  |     | NULL    |                |
		| smsalertnumber      | varchar(50)  | YES  |     | NULL    |                |
		| privacy             | int(11)      | NO   |     | 1       |                |
		+---------------------+--------------+------+-----+---------+----------------+
		66 rows in set (0.00 sec)
		Where Null="NO", the field is required.

=head1 KOHA_CONF and field mapping

Example XML stanza for LDAP configuration in KOHA_CONF.

 <config>
  ...
  <useldapserver>1</useldapserver>
  <!-- LDAP SERVER (optional) -->
  <ldapserver id="ldapserver">
    <hostname>localhost</hostname>
    <base>dc=metavore,dc=com</base>
    <user>cn=Manager,dc=metavore,dc=com</user>             <!-- DN, if not anonymous -->
    <pass>metavore</pass>          <!-- password, if not anonymous -->
    <replicate>1</replicate>       <!-- add new users from LDAP to Koha database -->
    <welcome>1</welcome>           <!-- send new users the welcome email when added via replicate -->
    <update>1</update>             <!-- update existing users in Koha database -->
    <auth_by_bind>0</auth_by_bind> <!-- set to 1 to authenticate by binding instead of
                                        password comparison, e.g., to use Active Directory -->
    <anonymous_bind>0</anonymous_bind> <!-- set to 1 if users should be searched using
                                            an anonymous bind, even when auth_by_bind is on -->
    <principal_name>%s@my_domain.com</principal_name>
                                   <!-- optional, for auth_by_bind: a printf format to make userPrincipalName from koha userid.
                                        Not used with anonymous_bind. -->
    <update_password>1</update_password> <!-- set to 0 if you don't want LDAP passwords
                                              synced to the local database -->
    <mapping>                  <!-- match koha SQL field names to your LDAP record field names -->
      <firstname    is="givenname"      ></firstname>
      <surname      is="sn"             ></surname>
      <address      is="postaladdress"  ></address>
      <city         is="l"              >Athens, OH</city>
      <zipcode      is="postalcode"     ></zipcode>
      <branchcode   is="branch"         >MAIN</branchcode>
      <userid       is="uid"            ></userid>
      <password     is="userpassword"   ></password>
      <email        is="mail"           ></email>
      <categorycode is="employeetype"   >PT</categorycode>
      <phone        is="telephonenumber"></phone>
    </mapping> 
  </ldapserver> 
 </config>

The <mapping> subelements establish the relationship between mysql fields and LDAP attributes. The element name
is the column in mysql, with the "is" characteristic set to the LDAP attribute name.  Optionally, any content
between the element tags is taken as the default value.  In this example, the default categorycode is "PT" (for
patron).  

=head1 CONFIGURATION

Once a user has been accepted by the LDAP server, there are several possibilities for how Koha will behave, depending on 
your configuration and the presence of a matching Koha user in your local DB:

                         LOCAL_USER
 OPTION UPDATE REPLICATE  EXISTS?  RESULT
   A1      1       1        1      OK : We're updating them anyway.
   A2      1       1        0      OK : We're adding them anyway.
   B1      1       0        1      OK : We update them.
   B2      1       0        0     FAIL: We cannot add new user.
   C1      0       1        1      OK : We do nothing.  (maybe should update password?)
   C2      0       1        0      OK : We add the new user.
   D1      0       0        1      OK : We do nothing.  (maybe should update password?)
   D2      0       0        0     FAIL: We cannot add new user.

Note: failure here just means that Koha will fallback to checking the local DB.  That is, a given user could login with
their LDAP password OR their local one.  If this is a problem, then you should enable update and supply a mapping for 
password.  Then the local value will be updated at successful LDAP login and the passwords will be synced.

If you choose NOT to update local users, the borrowers table will not be affected at all.
Note that this means that patron passwords may appear to change if LDAP is ever disabled, because
the local table never contained the LDAP values.  

=head2 auth_by_bind

Binds as the user instead of retrieving their record.  Recommended if update disabled.

=head2 principal_name

Provides an optional sprintf-style format for manipulating the userid before the bind.
Even though the userPrincipalName is one intended target, any uniquely identifying
attribute that the server allows to be used for binding could be used.

Currently, principal_name only operates when auth_by_bind is enabled.

=head2 update_password

If this tag is left out or set to a true value, then the user's LDAP password
will be stored (hashed) in the local Koha database. If you don't want this
to happen, then set the value of this to '0'. Note that if passwords are not
stored locally, and the connection to the LDAP system fails, then the users
will not be able to log in at all.

=head2 Active Directory 

The auth_by_bind and principal_name settings are recommended for Active Directory.

Under default Active Directory rules, we cannot determine the distinguishedName attribute from the Koha userid as reliably as
we would typically under openldap.  Instead of:

    distinguishedName: CN=barnes.7,DC=my_company,DC=com

We might get:

    distinguishedName: CN=Barnes\, Jim,OU=Test Accounts,OU=User Accounts,DC=my_company,DC=com

Matching that would require us to know more info about the account (firstname, surname) and to include punctuation and whitespace
in Koha userids.  But the userPrincipalName should be consistent, something like:

    userPrincipalName: barnes.7@my_company.com

Therefore it is often easier to bind to Active Directory with userPrincipalName, effectively the
canonical email address for that user, or what it would be if email were enabled for them.  If Koha userid values 
will match the username portion of the userPrincipalName, and the domain suffix is the same for all users, then use principal_name
like this:
    <principal_name>%s@core.my_company.com</principal_name>

The user of the previous example, barnes.7, would then attempt to bind as:
    barnes.7@core.my_company.com

=head1 SEE ALSO

CGI(3)

Net::LDAP()

XML::Simple()

Digest::MD5(3)

sprintf()

=cut

# For reference, here's an important difference in the data structure we rely on.
# ========================================
# Using attrs instead of {asn}->attributes
# ========================================
#
# 	LDAP key: ->{             cn} = ARRAY w/ 3 members.
# 	LDAP key: ->{             cn}->{           sss} = sss
# 	LDAP key: ->{             cn}->{   Steve Smith} = Steve Smith
# 	LDAP key: ->{             cn}->{Steve S. Smith} = Steve S. Smith
#
# 	LDAP key: ->{      givenname} = ARRAY w/ 1 members.
# 	LDAP key: ->{      givenname}->{Steve} = Steve
#
