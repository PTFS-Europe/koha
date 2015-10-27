#!/usr/bin/perl
package sipserver;

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin";
use Sys::Syslog qw(syslog);
use Net::Server::Fork;
use IO::Socket::INET;
use Socket qw(:DEFAULT :crlf);
require UNIVERSAL::require;

use Sip::Constants qw(:all);
use Sip::Configuration;
use Sip::Checksum qw(checksum verify_cksum);
use Sip::MsgType qw(handle login_core);

use base qw(Net::Server::Fork);

use constant LOG_SIP => "local6";    # Local alias for the logging facility

my %transports = (
    RAW    => \&raw_transport,
    telnet => \&telnet_transport,
);

#
# Read configuration
#
my $config = Sip::Configuration->new( $ARGV[0] );
my @parms;

#
# Ports to bind
#
foreach my $svc ( keys %{ $config->{listeners} } ) {
    push @parms, "port=" . $svc;
}

#
# Logging
#
# Log lines look like this:
# Jun 16 21:21:31 server08 steve_sip[19305]: ILS::Transaction::Checkout performing checkout...
# [  TIMESTAMP  ] [ HOST ] [ IDENT ]  PID  : Message...
#
# The IDENT is determined by config file 'server-params' arguments

#
# Server Management: set parameters for the Net::Server::PreFork
# module.  The module silently ignores parameters that it doesn't
# recognize, and complains about invalid values for parameters
# that it does.
#
if ( defined( $config->{'server-params'} ) ) {
    while ( my ( $key, $val ) = each %{ $config->{'server-params'} } ) {
        push @parms, $key . '=' . $val;
    }
}

#
# This is the main event.
__PACKAGE__->run(@parms);

#
# Child
#

# process_request is the callback used by Net::Server to handle
# an incoming connection request.

sub process_request {
    my $self = shift;
    my $service;
    my ( $sockaddr, $port, $proto );
    my $transport;

    $self->{config} = $config;

    my $sockname = getsockname(STDIN);
    my $peername = getpeername(STDIN);
    my ($iport, $iaddr);
    # Check if socket connection is IPv6 before resolving address
    my $family = Socket::sockaddr_family($sockname);
    if ( $family == AF_INET6 ) {
        ( $port, $sockaddr ) = sockaddr_in6($sockname);
        $sockaddr = Socket::inet_ntop( AF_INET6, $sockaddr );
        ( $iport, $iaddr) = sockaddr_in6($peername);
        $iaddr = Socket::inet_ntop( AF_INET6, $iaddr );
    }
    else {
        ( $port, $sockaddr ) = sockaddr_in($sockname);
        $sockaddr = inet_ntoa($sockaddr);
        ( $iport, $iaddr) = sockaddr_in($peername);
        $iaddr = inet_ntoa($iaddr);
    }
    syslog('LOG_INFO', "incoming connection from $iaddr");
    $proto = $self->{server}->{client}->NS_proto();

    $self->{service} = $config->find_service( $sockaddr, $port, $proto );

    if ( !defined( $self->{service} ) ) {
        syslog( "LOG_ERR",
            "process_request: Unknown recognized server connection: %s:%s/%s",
            $sockaddr, $port, $proto );
        die "process_request: Bad server connection";
    }
    syslog( 'LOG_INFO', "Connection on port:$port" );

    $transport = $transports{ $self->{service}->{transport} };

    if ( !defined($transport) ) {
        syslog( "LOG_WARNING", "Unknown transport '%s', dropping",
            $service->{transport} );
        return;
    }
    else {
        &$transport($self);
    }
    return;
}

#
# Transports
#

sub raw_transport {
    my $self = shift;
    my ($input);
    my $service = $self->{service};

    while ( !$self->{account} ) {
        local $SIG{ALRM} = sub { die "raw_transport Timed Out!\n"; };
        syslog( "LOG_DEBUG", "raw_transport: timeout is %d",
            $service->{timeout} );
        $input = read_request();
        if ( !$input ) {

            # EOF on the socket
            syslog( "LOG_INFO",
                "raw_transport: shutting down: EOF during login" );
            return;
        }
        $input =~ s/[\r\n]+$//sm;    # Strip off trailing line terminator(s)
        last if Sip::MsgType::handle( $input, $self, LOGIN );
    }

    syslog(
        "LOG_DEBUG",            "raw_transport: uname/inst: '%s/%s'",
        $self->{account}->{id}, $self->{account}->{institution}
    );

    $self->sip_protocol_loop();
    syslog( "LOG_INFO", "raw_transport: shutting down" );
}

sub get_clean_string {
    my $string = shift;
    if ( defined $string ) {
        syslog( "LOG_DEBUG", "get_clean_string  pre-clean(length %s): %s",
            length($string), $string );
        chomp($string);
        $string =~ s/^[^A-z0-9]+//;
        $string =~ s/[^A-z0-9]+$//;
        syslog( "LOG_DEBUG", "get_clean_string post-clean(length %s): %s",
            length($string), $string );
    }
    else {
        syslog( "LOG_INFO", "get_clean_string called on undefined" );
    }
    return $string;
}

sub get_clean_input {
    local $/ = "\012";
    my $in = <STDIN>;
    $in = get_clean_string($in);
    while ( my $extra = <STDIN> ) {
        syslog( "LOG_ERR", "get_clean_input got extra lines: %s", $extra );
    }
    return $in;
}

sub telnet_transport {
    my $self = shift;
    my ( $uid, $pwd );
    my $strikes = 3;
    my $account = undef;
    my $input;
    my $config = $self->{config};
    my $timeout = $self->{service}->{timeout} || $config->{timeout} || 30;
    syslog( "LOG_DEBUG", "telnet_transport: timeout is %s", $timeout );

    eval {
        local $SIG{ALRM} =
          sub { die "telnet_transport: Timed Out ($timeout seconds)!\n"; };
        local $| = 1;    # Unbuffered output
        $/ = "\015";     # Internet Record Separator (lax version)
                         # Until the terminal has logged in, we don't trust it
                         # so use a timeout to protect ourselves from hanging.

        while ( $strikes-- ) {
            print "login: ";
            alarm $timeout;

            # $uid = &get_clean_input;
            $uid = <STDIN>;
            print "password: ";

            # $pwd = &get_clean_input || '';
            $pwd = <STDIN>;
            alarm 0;

            syslog( "LOG_DEBUG",
                "telnet_transport 1: uid length %s, pwd length %s",
                length($uid), length($pwd) );
            $uid = get_clean_string($uid);
            $pwd = get_clean_string($pwd);
            syslog( "LOG_DEBUG",
                "telnet_transport 2: uid length %s, pwd length %s",
                length($uid), length($pwd) );

            if ( exists( $config->{accounts}->{$uid} )
                && ( $pwd eq $config->{accounts}->{$uid}->{password} ) )
            {
                $account = $config->{accounts}->{$uid};
                Sip::MsgType::login_core( $self, $uid, $pwd ) and last;
            }
            syslog(
                "LOG_WARNING",
                "Invalid login attempt: '%s'",
                ( $uid || '' )
            );
            print("Invalid login$CRLF");
        }
    };    # End of eval

    if ($@) {
        syslog( "LOG_ERR", "telnet_transport: Login timed out" );
        die "Telnet Login Timed out";
    }
    elsif ( !defined($account) ) {
        syslog( "LOG_ERR", "telnet_transport: Login Failed" );
        die "Login Failure";
    }
    else {
        print "Login OK.  Initiating SIP$CRLF";
    }

    $self->{account} = $account;
    syslog( "LOG_DEBUG", "telnet_transport: uname/inst: '%s/%s'",
        $account->{id}, $account->{institution} );
    $self->sip_protocol_loop();
    syslog( "LOG_INFO", "telnet_transport: shutting down" );
}

#
# The terminal has logged in, using either the SIP login process
# over a raw socket, or via the pseudo-unix login provided by the
# telnet transport.  From that point on, both the raw and the telnet
# processes are the same:
sub sip_protocol_loop {
    my $self    = shift;
    my $service = $self->{service};
    my $config  = $self->{config};

    # The spec says the first message will be:
    # 	SIP v1: SC_STATUS
    # 	SIP v2: LOGIN (or SC_STATUS via telnet?)
    # But it might be SC_REQUEST_RESEND.  As long as we get
    # SC_REQUEST_RESEND, we keep waiting.

    # Comprise reports that no other ILS actually enforces this
    # constraint, so we'll relax about it too.
    # Using the SIP "raw" login process, rather than telnet,
    # requires the LOGIN message and forces SIP 2.00.  In that
    # case, the LOGIN message has already been processed (above).
    #
    # In short, we'll take any valid message here.
    #my $expect = SC_STATUS;

    while ( my $inputbuf = read_request() ) {
        if ( !defined $inputbuf ) {
            return;       # EOF
        }

        unless ($inputbuf) {
            syslog( "LOG_ERR", "sip_protocol_loop: empty input skipped" );
            print("96$CR");
            next;
        }

        # end cheap input hacks
        my $status = Sip::MsgType::handle( $inputbuf, $self, q{} );
        if ( !$status ) {
            syslog(
                "LOG_ERR",
                "sip_protocol_loop: failed to handle %s",
                substr( $inputbuf, 0, 2 )
            );
        }
        next if $status eq REQUEST_ACS_RESEND;
    }
    return;
}

sub read_request {
    my $raw_length;
    local $/ = "\015";

    # proper SPEC: (octal) \015 = (hex) x0D = (dec) 13 = (ascii) carriage return
    my $buffer = <STDIN>;
    if ( defined $buffer ) {
        STDIN->flush();    # clear an extra linefeed
        chomp $buffer;
        syslog( "LOG_INFO", "read_SIP_packet, INPUT MSG: '$buffer'" );
        $raw_length = length $buffer;
        $buffer =~ s/^\s*[^A-z0-9]+//s
          ; # Every line must start with a "real" character.  Not whitespace, control chars, etc.
        $buffer =~ s/[^A-z0-9]+$//s;
        $buffer =~ s/\015?\012//g;    # Extra line breaks must die
        $buffer =~ s/\015?\012//s;    # Extra line breaks must die
        $buffer =~ s/\015*\012*$//s;

    # treat as one line to include the extra linebreaks we are trying to remove!
    }
    else {
        syslog( 'LOG_DEBUG', 'EOF returned on read' );
        return;
    }
    my $len = length $buffer;
    if ( $len != $raw_length ) {
        my $trim = $raw_length - $len;
        syslog( "LOG_DEBUG", "read_SIP_packet, trimmed $trim character(s) " );
    }

    syslog( "LOG_INFO", "INPUT MSG: '$buffer'" );
    return $buffer;
}

1;
__END__
