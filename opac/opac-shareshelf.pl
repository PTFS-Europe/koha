#!/usr/bin/perl

# Copyright 2013 Rijksmuseum
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

use constant KEYLENGTH   => 10;
use constant SHELVES_URL => '/cgi-bin/koha/opac-shelves.pl?display=privateshelves&viewshelf=';

use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Letters;
use C4::Output qw( output_html_with_http_headers );

use Koha::Email;
use Koha::Patrons;
use Koha::Virtualshelves;
use Koha::Virtualshelfshares;

# if virtualshelves is disabled, leave immediately
our $query = CGI->new;
if ( !C4::Context->preference('virtualshelves') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

#-------------------------------------------------------------------------------

our ( $op, $template, $loggedinuser, $cookie );
$op = $query->param('op') // q{show};

my $pvar = _init();

( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => 'opac-shareshelf.tt',
        query         => $query,
        type          => "opac",
    }
);

if ( !$pvar->{errcode} ) {
    show_invite($pvar)    if $op eq 'show';
    show_accept($pvar)    if $op eq 'accept';
    confirm_invite($pvar) if $op eq 'cud-invite';
    handle_accept($pvar)  if $op eq 'cud-accept';
}

load_template_vars($pvar);
output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };

#-------------------------------------------------------------------------------

sub _init {
    my $param = {};
    $param->{shelfnumber} = $query->param('shelfnumber')    || 0;
    $param->{addrlist}    = $query->param('invite_address') || '';
    $param->{key}         = $query->param('key')            || '';
    $param->{appr_addr}   = [];
    $param->{fail_addr}   = [];
    $param->{errcode}     = check_common_errors($param);

    # trim email address
    if ( $param->{addrlist} ) {
        $param->{addrlist} =~ s|^\s+||;
        $param->{addrlist} =~ s|\s+$||;
    }

    #get some list details
    my $shelf;
    my $shelfnumber = $param->{shelfnumber};
    $shelf              = Koha::Virtualshelves->find($shelfnumber) unless $param->{errcode};
    $param->{shelfname} = $shelf ? $shelf->shelfname : q||;
    $param->{owner}     = $shelf ? $shelf->owner     : -1;
    $param->{public}    = $shelf ? $shelf->public    : 0;

    return $param;
}

sub check_common_errors {
    my ($param) = @_;
    if ( $op !~ /^(show|accept|cud-invite|cud-accept)$/ ) {
        return 1;    #unknown operation
    }
    if ( $param->{shelfnumber} !~ /^\d+$/ ) {
        return 2;    #invalid shelf number
    }
    if ( !C4::Context->preference('OpacAllowSharingPrivateLists') ) {
        return 3;    #not or no longer allowed?
    }
    return;
}

sub show_invite {
    my ($param) = @_;
    check_owner_category($param);
}

sub confirm_invite {
    my ($param) = @_;
    return unless check_owner_category($param);
    process_addrlist($param);
    if ( @{ $param->{appr_addr} } ) {
        send_invitekey($param);
        $op = 'invited';
    } else {
        $param->{errcode} = 6;    #not one valid address
    }
}

sub show_accept {
    my ($param) = @_;
    $template->param( key => $param->{key} );

    # Main reason for checking the key here is not to expose shelfname
    # to people who dont have the key
    my $key            = keytostring( stringtokey( $param->{key}, 0 ), 1 );
    my $shared_shelves = Koha::Virtualshelfshares->search(
        {
            shelfnumber => $param->{shelfnumber},
            invitekey   => $key,
        }
    );
    return if $shared_shelves->count;
    $param->{errcode} = 7;    # not accepted: key invalid or expired
}

sub handle_accept {
    my ($param) = @_;

    my $shelfnumber = $param->{shelfnumber};
    my $shelf       = Koha::Virtualshelves->find($shelfnumber);

    # The key for accepting is checked later in Koha::Virtualshelfshare
    # You must not be the owner and the list must be private
    if ( !$shelf ) {
        $param->{errcode} = 2;
    } elsif ( $shelf->public ) {
        $param->{errcode} = 5;
    } elsif ( $shelf->owner == $loggedinuser ) {
        $param->{errcode} = 8;
    }
    return if $param->{errcode};

    # Look for shelfnumber and invitekey in shares, expiration check later
    my $key            = keytostring( stringtokey( $param->{key}, 0 ), 1 );
    my $shared_shelves = Koha::Virtualshelfshares->search(
        {
            shelfnumber => $param->{shelfnumber},
            invitekey   => $key,
        }
    );
    my $shared_shelf =
        $shared_shelves ? $shared_shelves->next : undef;    # we pick the first, but there should only be one

    if ($shared_shelf) {
        my $is_accepted = eval { $shared_shelf->accept( $key, $loggedinuser ) };
        if ($is_accepted) {
            notify_owner($param);

            #redirect to view of this shared list
            print $query->redirect(
                -uri    => SHELVES_URL . $param->{shelfnumber},
                -cookie => $cookie,
            );
            exit;
        }
    }
    $param->{errcode} = 7;    # not accepted: key invalid or expired
}

sub notify_owner {
    my ($param) = @_;

    my $patron = Koha::Patrons->find( $param->{owner} );
    return unless $patron;

    my $toaddr = $patron->notice_email_address or return;

    #prepare letter
    my $letter = C4::Letters::GetPreparedLetter(
        module      => 'lists',
        letter_code => 'SHARE_ACCEPT',
        branchcode  => C4::Context->userenv->{"branch"},
        lang        => $patron->lang,
        tables      => { borrowers => $loggedinuser, },
        substitute  => { listname  => $param->{shelfname}, },
    );

    #send letter to queue
    C4::Letters::EnqueueLetter(
        {
            letter                 => $letter,
            message_transport_type => 'email',
            from_address           => C4::Context->preference('KohaAdminEmailAddress'),
            to_address             => $toaddr,
        }
    );
}

sub process_addrlist {
    my ($param) = @_;
    my @temp    = split /[,:;]/, $param->{addrlist};
    my @appr_addr;
    my @fail_addr;
    foreach my $a (@temp) {
        $a =~ s/^\s+//;
        $a =~ s/\s+$//;
        if ( Koha::Email->is_valid($a) ) {
            push @appr_addr, $a;
        } else {
            push @fail_addr, $a;
        }
    }
    $param->{appr_addr} = \@appr_addr;
    $param->{fail_addr} = \@fail_addr;
}

sub send_invitekey {
    my ($param) = @_;
    my $fromaddr = C4::Context->preference('KohaAdminEmailAddress');
    my $url =
          C4::Context->preference('OPACBaseURL')
        . "/cgi-bin/koha/opac-shareshelf.pl?shelfnumber="
        . $param->{shelfnumber}
        . "&op=accept&key=";

    #TODO Waiting for the right http or https solution (BZ 8952 a.o.)

    my @ok;    #the addresses that were processed well
    foreach my $a ( @{ $param->{appr_addr} } ) {
        my @newkey = randomlist( KEYLENGTH, 64 );    #generate a new key

        #add a preliminary share record
        my $shelf     = Koha::Virtualshelves->find( $param->{shelfnumber} );
        my $key       = keytostring( \@newkey, 1 );
        my $is_shared = eval { $shelf->share($key); };

        # TODO Better error handling, catch the exceptions
        if ( $@ or not $is_shared ) {
            push @{ $param->{fail_addr} }, $a;
            next;
        }
        push @ok, $a;

        #prepare letter
        my $letter = C4::Letters::GetPreparedLetter(
            module      => 'lists',
            letter_code => 'SHARE_INVITE',
            branchcode  => C4::Context->userenv->{"branch"},
            lang        => 'default',                        # Not sure how we could use something more useful else here
            tables      => { borrowers => $loggedinuser, },
            substitute  => {
                listname => $param->{shelfname},
                shareurl => $url . keytostring( \@newkey, 0 ),
            },
        );

        #send letter to queue
        C4::Letters::EnqueueLetter(
            {
                letter                 => $letter,
                message_transport_type => 'email',
                from_address           => $fromaddr,
                to_address             => $a,
            }
        );
    }
    $param->{appr_addr} = \@ok;
}

sub check_owner_category {
    my ($param) = @_;

    #sharing user should be the owner
    #list should be private
    $param->{errcode} = 4 if $param->{owner} != $loggedinuser;
    $param->{errcode} = 5 if !$param->{errcode} && $param->{public};
    return !defined $param->{errcode};
}

sub load_template_vars {
    my ($param) = @_;
    my $appr    = join '; ', @{ $param->{appr_addr} };
    my $fail    = join '; ', @{ $param->{fail_addr} };
    $template->param(
        op              => $op,
        errcode         => $param->{errcode},
        shelfnumber     => $param->{shelfnumber},
        shelfname       => $param->{shelfname},
        approvedaddress => $appr,
        failaddress     => $fail,
    );
}

sub randomlist {

    #uses rand, safe enough for this application but not for more sensitive data
    my ( $length, $base ) = @_;
    return map { int( rand($base) ); } 1 .. $length;
}

sub keytostring {
    my ( $keyref, $flgBase64 ) = @_;
    if ($flgBase64) {
        my $alphabet = [ 'A' .. 'Z', 'a' .. 'z', 0 .. 9, '+', '/' ];
        return join '', map { alphabet_char( $_, $alphabet ); } @$keyref;
    }
    return join '', map { sprintf( "%02d", $_ ); } @$keyref;
}

sub stringtokey {
    my ( $str, $flgBase64 ) = @_;
    my @temp = split '', $str || '';
    if ($flgBase64) {
        my $alphabet = [ 'A' .. 'Z', 'a' .. 'z', 0 .. 9, '+', '/' ];
        return [ map { alphabet_ordinal( $_, $alphabet ); } @temp ];
    }
    return [] if $str !~ /^\d+$/;
    my @retval;
    for ( my $i = 0 ; $i < @temp - 1 ; $i += 2 ) {
        push @retval, $temp[$i] * 10 + $temp[ $i + 1 ];
    }
    return \@retval;
}

sub alphabet_ordinal {
    my ( $char, $alphabet ) = @_;
    for my $ord ( 0 .. $#$alphabet ) {
        return $ord if $char eq $alphabet->[$ord];
    }
    return '';    #ignore missing chars
}

sub alphabet_char {

    #reverse operation for ordinal; ignore invalid numbers
    my ( $num, $alphabet ) = @_;
    return $num =~ /^\d+$/ && $num <= $#$alphabet ? $alphabet->[$num] : '';
}
