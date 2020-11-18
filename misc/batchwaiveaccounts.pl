#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;
use Pod::Usage;
use IO::File;

use Koha::Script;

my ( $help, $confirm );
GetOptions(
    'c|confirm' => \$confirm,
    'h|help'    => \$help,
);

pod2usage(1) if ( $help || !$confirm );

for my $file (@ARGV) {
    say "Finding accountnumbers in file $file";
    my $fh;
    open( $fh, '<', $file ) or say "Error: '$file' $!" and next;

    while (<$fh>) {
        my $accountline_id = $_;
        $accountline_id =~ s/$1/\n/g if $accountline_id =~ m/(\r\n?|\n\r?)/;
        chomp $accountline_id;
        my $debt = Koha::Account::Lines->find($accountline_id);

        next and warn "Skipping $accountline_id; Not a debt"
          if $debt->is_credit;
        next and warn "Skipping $accountline_id; Is a PAYOUT"
          if $debt->debit_type_code eq 'PAYOUT';
        next and warn "Skipping $accountline_id; Debit is paid"
          if $debt->amount != $debt->amountoutstanding;

        my $writeoff;
        $debt->_result->result_source->schema->txn_do(
            sub {

                # A 'writeoff' is a 'credit'
                $writeoff = Koha::Account::Line->new(
                    {
                        date              => \'NOW()',
                        amount            => 0 - $debt->amount,
                        credit_type_code  => 'WRITEOFF',
                        status            => 'ADDED',
                        amountoutstanding => 0 - $debt->amount,
                        manager_id        => undef,
                        borrowernumber    => $debt->borrowernumber,
                        interface         => 'intranet',
                        branchcode        => undef,
                    }
                )->store();

                my $writeoff_offset = Koha::Account::Offset->new(
                    {
                        credit_id => $writeoff->accountlines_id,
                        type      => 'WRITEOFF',
                        amount    => $debt->amount
                    }
                )->store();

                # Link writeoff to charge
                $writeoff->apply(
                    {
                        debits      => [$debt],
                        offset_type => 'WRITEOFF'
                    }
                );
                $writeoff->status('APPLIED')->store();

                # Update status of original debit
                $debt->status('FORGIVEN')->store;
            }
        );

        print "$accountline_id written off\n";
    }
}

exit(0);

__END__

=head1 NAME

batchwaiveaccounts.pl

=head1 SYNOPSIS

    ./batchwaiveaccounts.pl --confirm file1 [file2 ... fileN]

This script batch waives accounts.

=head1 OPTIONS

=over 8

=item B<-h|--help>

prints this help message

=back

=head1 AUTHOR

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=head1 COPYRIGHT

Copyright 2020 PTFS Europe

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Koha is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 DISCLAIMER OF WARRANTY

Koha is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=cut
