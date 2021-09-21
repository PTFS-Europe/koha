package C4::ClassSplitRoutine::ETF;

# Copyright 2018 Koha Development Team
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
use Library::CallNumber::LC;

=head1 NAME

C4::ClassSplitRoutine::ETF - ETF call number split method, based on LCC

=head1 SYNOPSIS

use C4::ClassSplitRoutine;

my $cn_split = C4::ClassSplitRoutine::ETF::split_callnumber($cn_item);

=head1 FUNCTIONS

=head2 split_callnumber

  my $cn_split = C4::ClassSplitRoutine::ETF::split_callnumber($cn_item);

=cut

sub split_callnumber {
    my ($fcn) = @_;

    my $part  = '';
    my $part1 = '';
    my $part2 = '';

    my @orig_parts  = ();
    my @final_parts = ();

    # Split call numbers based on spaces
    push @orig_parts, split /\s+/, $fcn;

    for my $part (@orig_parts) {
        if ( index( $part, '.' ) != -1 && length($part) > 7 ) {

            # the part contains at least one dot and has to be split
            my $sub_part  = '';
            my @sub_parts = ();

            push @sub_parts, split /\./, $part;

            $sub_part = $sub_parts[0];

            for ( my $i = 1 ; $i < scalar @sub_parts ; $i++ ) {
                if ( length($sub_part) + length( $sub_parts[$i] ) >= 7 ) {
                    push @final_parts, $sub_part;
                    $sub_part = '.' . $sub_parts[$i];
                } else {
                    $sub_part .= '.' . $sub_parts[$i];
                }
            }

            if ( rindex( $part, '.' ) == length($part) ) {

                #the part ends on a dot but that was dropped while splitting: add it again.
                $sub_part .= '.';
            }

            push @final_parts, $sub_part;
        } else {

            # no dot(s) in this part: add as-is
            push @final_parts, $part;
        }
    }

    return @final_parts;
}

1;

=head1 AUTHOR

Kris Sinnaeve <kris.sinnaeve@etf.edu>

=cut
