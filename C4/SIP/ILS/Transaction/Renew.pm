#
# Status of a Renew Transaction
#

package C4::SIP::ILS::Transaction::Renew;

use warnings;
use strict;

use C4::Circulation;
use Koha::Patrons;
use Koha::DateUtils;

use parent qw(C4::SIP::ILS::Transaction);

my %fields = (
    renewal_ok => 0,
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();

    foreach my $element (keys %fields) {
        $self->{_permitted}->{$element} = $fields{$element};
    }

    @{$self}{keys %fields} = values %fields;	# overkill?
    return bless $self, $class;
}

sub do_renew_for  {
    my $self = shift;
    my $borrower = shift;
    my ($renewokay,$renewerror) = CanBookBeRenewed($borrower->{borrowernumber},$self->{item}->{itemnumber});
    if ($renewokay) { # ok so far check charges
        my ($fee, undef) = GetIssuingCharges($self->{item}->{itemnumber}, $self->{patron}->{borrowernumber});
        if ($fee > 0) {
            $self->{sip_fee_type} = '06';
            $self->{fee_amount} = sprintf '%.2f',$fee;
            if ($self->{fee_ack} eq 'N') {
                $renewokay = 0;
            }
        }

    }
    if ($renewokay){
        my $issue = AddIssue( $borrower, $self->{item}->id, undef, 0 );
        $self->{due} = $self->duedatefromissue($issue, $self->{item}->{itemnumber});
        $self->renewal_ok(1);
    } else {
        $renewerror=~s/on_reserve/Item unavailable due to outstanding holds/;
        $renewerror=~s/too_many/Item has reached maximum renewals/;
        $renewerror=~s/too_unseen/Item has reached maximum consecutive renewals without being seen/;
        $renewerror=~s/item_denied_renewal/Item renewal is not allowed/;
        $self->screen_msg($renewerror);
        $self->renewal_ok(0);
    }
    $self->ok(1);
    return;
}

sub do_renew {
    my $self = shift;
    my $patron = Koha::Patrons->find( $self->{patron}->borrowernumber );
    $patron or return; # FIXME we should log that
    return $self->do_renew_for($patron->unblessed);
}

1;
