#
# An object to handle checkout status
#

package C4::SIP::ILS::Transaction::Checkout;

use warnings;
use strict;

use POSIX qw(strftime);
use Sys::Syslog qw(syslog);
use Data::Dumper;
use CGI qw ( -utf8 );

use C4::SIP::ILS::Transaction;

use C4::Context;
use C4::Circulation;
use C4::Members;
use C4::Reserves qw(ModReserveFill);
use C4::Debug;
use Koha::DateUtils;

use parent qw(C4::SIP::ILS::Transaction);

our $debug;


# Most fields are handled by the Transaction superclass
my %fields = (
	      security_inhibit => 0,
	      due              => undef,
	      renew_ok         => 0,
	);

sub new {
    my $class = shift;;
    my $self = $class->SUPER::new();
    foreach my $element (keys %fields) {
		$self->{_permitted}->{$element} = $fields{$element};
    }
    @{$self}{keys %fields} = values %fields;
#    $self->{'due'} = time() + (60*60*24*14); # two weeks hence
	$debug and warn "new ILS::Transaction::Checkout : " . Dumper $self;
    return bless $self, $class;
}

sub do_checkout {
	my $self = shift;
	syslog('LOG_DEBUG', "ILS::Transaction::Checkout performing checkout...");
	my $shelf          = $self->{item}->hold_shelf;
	my $barcode        = $self->{item}->id;
	my $patron_barcode = $self->{patron}->id;
        my $overridden_duedate; # usually passed as undef to AddIssue
	$debug and warn "do_checkout: patron (" . $patron_barcode . ")";
    my $patron = Koha::Patrons->find( { cardnumber => $patron_barcode } );
    my $borrower = $patron->unblessed;
	$debug and warn "do_checkout borrower: . " . Dumper $borrower;
    my ($issuingimpossible, $needsconfirmation) = _can_we_issue($patron, $barcode,
        C4::Context->preference("AllowItemsOnHoldCheckout")
    );

    my $noerror=1;  # If set to zero we block the issue
    if (keys %{$issuingimpossible}) {
        foreach (keys %{$issuingimpossible}) {
            # do something here so we pass these errors
            $self->screen_msg("Issue failed : $_");
            $noerror = 0;
            last;
        }
    } else {
        foreach my $confirmation (keys %{$needsconfirmation}) {
            if ($confirmation eq 'RENEW_ISSUE'){
                $self->screen_msg("Item already checked out to you: renewing item.");
            } elsif ($confirmation eq 'RESERVED' or $confirmation eq 'RESERVE_WAITING') {
                my $x = $self->{item}->available($patron_barcode);
                if ($x) {
                    $self->screen_msg("Item was reserved for you.");
                } else {
                    $self->screen_msg("Item is reserved for another patron upon return.");
                    $noerror = 0;
                }
            } elsif ($confirmation eq 'ISSUED_TO_ANOTHER') {
                $self->screen_msg("Item already checked out to another patron.  Please return item for check-in.");
                $noerror = 0;
                last;
            } elsif ($confirmation eq 'DEBT') {
                $self->screen_msg('Outstanding Fines block issue');
                $noerror = 0;
                last;
            } elsif ($confirmation eq 'HIGHHOLDS') {
                $overridden_duedate = $needsconfirmation->{$confirmation}->{returndate};
                $self->screen_msg('Loan period reduced for high-demand item');
            } elsif ($confirmation eq 'RENTALCHARGE') {
                if ($self->{fee_ack} ne 'Y') {
                    $noerror = 0;
                    last;
                }
             } elsif ($confirmation eq 'PREVISSUE') {
                $self->screen_msg("This item was previously checked out by you");
                last;
            } else {
                # We've been returned a case other than those above
                $self->screen_msg("Item cannot be issued: $confirmation");
                $noerror = 0;
                syslog('LOG_DEBUG', "Blocking checkout Reason:$confirmation");
                last;
            }
        }
    }
    my $itemnumber = $self->{item}->{itemnumber};
    foreach (@$shelf) {
        $debug and warn "shelf has ($_->{itemnumber} for $_->{borrowernumber}). this is ($itemnumber, $self->{patron}->{borrowernumber})";
        ($_->{itemnumber} eq $itemnumber) or next;    # skip it if not this item
        ($_->{borrowernumber} == $self->{patron}->{borrowernumber}) and last;
            # if item was waiting for this patron, we're done.  AddIssue takes care of the "W" hold.
        $debug and warn "Item is on hold shelf for another patron.";
        $self->screen_msg("Item is on hold shelf for another patron.");
        $noerror = 0;
    }
    my ($fee, undef) = GetIssuingCharges($itemnumber, $self->{patron}->{borrowernumber});
    if ( $fee > 0 ) {
        $self->{sip_fee_type} = '06';
        $self->{fee_amount} = sprintf '%.2f', $fee;
        if ($self->{fee_ack} eq 'N' ) {
            $noerror = 0;
        }
    }
	unless ($noerror) {
		$debug and warn "cannot issue: " . Dumper($issuingimpossible) . "\n" . Dumper($needsconfirmation);
		$self->ok(0);
		return $self;
	}
	# can issue
	$debug and warn "do_checkout: calling AddIssue(\$borrower,$barcode, $overridden_duedate, 0)\n"
		# . "w/ \$borrower: " . Dumper($borrower)
		. "w/ C4::Context->userenv: " . Dumper(C4::Context->userenv);
    my $issue = AddIssue( $borrower, $barcode, $overridden_duedate, 0 );
    $self->{due} = $self->duedatefromissue($issue, $itemnumber);

	$self->ok(1);
	return $self;
}

sub _can_we_issue {
    my ( $patron, $barcode, $pref ) = @_;

    my ( $issuingimpossible, $needsconfirmation, $alerts ) =
      CanBookBeIssued( $patron, $barcode, undef, 0, $pref );
    for my $href ( $issuingimpossible, $needsconfirmation ) {

        # some data is returned using lc keys we only
        foreach my $key ( keys %{$href} ) {
            if ( $key =~ m/[^A-Z_]/ ) {
                delete $href->{$key};
            }
        }
    }
    return ( $issuingimpossible, $needsconfirmation );
}

1;
__END__
