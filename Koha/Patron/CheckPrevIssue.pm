package Koha::Patron::CheckPrevIssue;

# This file is part of Koha.
#
# Copyright (C) 2014 PTFS Europe
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

use C4::Context;
use Koha::Categories;
use Koha::Issues;
use Koha::OldIssues;

use parent qw( Exporter );

our @EXPORT = qw(
        WantsCheckPrevIssue
        CheckPrevIssue
);

=head1 NAME

Koha::Patron::CheckPrevIssue - Manage Previous Issue preferences & searches.

=head1 SYNOPSIS

Provide a feature to check whether a patron has previously checked out items
associated with a a biblio.

=head1 DESCRIPTION

CheckPrevIssue is a feature that allows administrators of a Koha instance to
enable a warning when items are lent to patrons when they've already borrowed
it in the past.

An example use case might be a housebound delivery service, where volunteers
pick stock for housebound patrons.  The volunteers might not have an
exhaustive list of books borrowed in the past, so they would benefit from
being warned when they are about to check out such a book to that patron.

The module introduces:

=over

=item a master syspref in the Patrons section:

=over

=item Do not

=item Unless overridden, do not

=item Unless overridden, do

=item Do

=back

=item per patron category switches:

=over

=item Inherit from system preferences.

=item Yes and try to override system preferences.

=item No and try to override system preferences.

=back

=item per patron switches

=over

=item Inherit from wider settings.

=item Yes and try to override settings.

=item No and try to override settings.

=back

=back

=head1 FUNCTIONS

=cut

=head2 WantsCheckPrevIssue

    $wantsCheckPrevIssue = WantsCheckPrevIssue($patron, $syspref);

Return 1 if Koha needs to perform PrevIssue checking, else 0.

$PATRON is used to determine patron and patron category checkPrevIssue level
setting.  $SYSPREF conteins the system-wide checkPrevIssue level setting.

=cut

sub WantsCheckPrevIssue {
    my ( $patron, $syspref ) = @_;

    # Simple cases
    ## Hard syspref trumps all
    return 1 if ($syspref eq 'hardyes');
    return 0 if ($syspref eq 'hardno');
    ## Now, patron pref trumps all
    my $checkPrevIssueByBrw = $patron->{checkprevissue};
    return 1 if ($checkPrevIssueByBrw eq 'yes');
    return 0 if ($checkPrevIssueByBrw eq 'no');

    # More complex: patron inherits -> determine category preference
    my $checkPrevIssueByCat =
        Koha::Categories->find($patron->{categorycode})->checkprevissue;
    return 1 if ($checkPrevIssueByCat eq 'yes');
    return 0 if ($checkPrevIssueByCat eq 'no');

    # Finally: category preference is inherit, default to 0
    if ($syspref eq 'softyes') {
        return 1;
    } else {
        return 0;
    }
}

=head2 CheckPrevIssue

    $checkPrevIssue = CheckPrevIssue($patron, $item);

Return 1 if the bib associated with $ITEM has previously been checked out to
$PATRON, 0 otherwise.

=cut

sub CheckPrevIssue {
    my ( $patron, $item ) = @_;

    # Find all items for bib and extract item numbers.
    my @items = Koha::Items->search({biblionumber => $item->{biblionumber}});
    my @item_nos;
    foreach my $item (@items) {
        push @item_nos, $item->itemnumber;
    }

    # Create (old)issues search criteria
    my $criteria = {
        borrowernumber => $patron->{borrowernumber},
        itemnumber => \@item_nos,
    };

    # Check current issues table
    my $issues = Koha::Issues->search($criteria);
    return 1 if $issues->count; # 0 || N

    # Check old issues table
    my $old_issues = Koha::OldIssues->search($criteria);
    return $old_issues->count;  # 0 || N
}

1;

__END__

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut
