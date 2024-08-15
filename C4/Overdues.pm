package C4::Overdues;


# Copyright 2000-2002 Katipo Communications
# copyright 2010 BibLibre
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
use Date::Calc qw( Today );
use Date::Manip qw( UnixDate );
use List::MoreUtils qw( uniq );
use POSIX qw( ceil floor );
use Locale::Currency::Format 1.28 qw( currency_format FMT_SYMBOL );
use Carp qw( carp );

use C4::Accounts;
use C4::Context;
use Koha::Account::Lines;
use Koha::Account::Offsets;
use Koha::DateUtils qw( output_pref );
use Koha::Libraries;
use Koha::Recalls;
use Koha::Logger;
use Koha::Patrons;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA = qw(Exporter);

    # subs to rename (and maybe merge some...)
    @EXPORT_OK = qw(
      CalcFine
      Getoverdues
      checkoverdues
      UpdateFine
      GetFine
      GetBranchcodesWithOverdueRules
      get_chargeable_units
      GetOverduesForBranch
      GetOverdueMessageTransportTypes
      parse_overdues_letter
      GetIssuesIteminfo
    );
}

=head1 NAME

C4::Circulation::Fines - Koha module dealing with fines

=head1 SYNOPSIS

  use C4::Overdues;

=head1 DESCRIPTION

This module contains several functions for dealing with fines for
overdue items. It is primarily used by the 'misc/fines2.pl' script.

=head1 FUNCTIONS

=head2 Getoverdues

  $overdues = Getoverdues( { minimumdays => 1, maximumdays => 30 } );

Returns the list of all overdue books, with their itemtype.

C<$overdues> is a reference-to-array. Each element is a
reference-to-hash whose keys are the fields of the issues table in the
Koha database.

=cut

#'
sub Getoverdues {
    my $params = shift;
    my $dbh = C4::Context->dbh;
    my $statement;
    if ( C4::Context->preference('item-level_itypes') ) {
        $statement = "
   SELECT issues.*, items.itype as itemtype, items.homebranch, items.barcode, items.itemlost, items.replacementprice, items.biblionumber, items.holdingbranch
     FROM issues 
LEFT JOIN items       USING (itemnumber)
    WHERE date_due < NOW()
";
    } else {
        $statement = "
   SELECT issues.*, biblioitems.itemtype, items.itype, items.homebranch, items.barcode, items.itemlost, replacementprice, items.biblionumber, items.holdingbranch
     FROM issues 
LEFT JOIN items       USING (itemnumber)
LEFT JOIN biblioitems USING (biblioitemnumber)
    WHERE date_due < NOW()
";
    }

    my @bind_parameters;
    if ( exists $params->{'minimumdays'} and exists $params->{'maximumdays'} ) {
        $statement .= ' AND TO_DAYS( NOW() )-TO_DAYS( date_due ) BETWEEN ? and ? ';
        push @bind_parameters, $params->{'minimumdays'}, $params->{'maximumdays'};
    } elsif ( exists $params->{'minimumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) > ? ';
        push @bind_parameters, $params->{'minimumdays'};
    } elsif ( exists $params->{'maximumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) < ? ';
        push @bind_parameters, $params->{'maximumdays'};
    }
    $statement .= 'ORDER BY borrowernumber';
    my $sth = $dbh->prepare( $statement );
    $sth->execute( @bind_parameters );
    return $sth->fetchall_arrayref({});
}


=head2 checkoverdues

    ($count, $overdueitems) = checkoverdues($borrowernumber);

Returns a count and a list of overdueitems for a given borrowernumber

=cut

sub checkoverdues {
    my $borrowernumber = shift or return;
    my $sth = C4::Context->dbh->prepare(
        "SELECT biblio.*, items.*, issues.*,
                biblioitems.volume,
                biblioitems.number,
                biblioitems.itemtype,
                biblioitems.isbn,
                biblioitems.issn,
                biblioitems.publicationyear,
                biblioitems.publishercode,
                biblioitems.volumedate,
                biblioitems.volumedesc,
                biblioitems.collectiontitle,
                biblioitems.collectionissn,
                biblioitems.collectionvolume,
                biblioitems.editionstatement,
                biblioitems.editionresponsibility,
                biblioitems.illus,
                biblioitems.pages,
                biblioitems.notes,
                biblioitems.size,
                biblioitems.place,
                biblioitems.lccn,
                biblioitems.url,
                biblioitems.cn_source,
                biblioitems.cn_class,
                biblioitems.cn_item,
                biblioitems.cn_suffix,
                biblioitems.cn_sort,
                biblioitems.totalissues
         FROM issues
         LEFT JOIN items       ON issues.itemnumber      = items.itemnumber
         LEFT JOIN biblio      ON items.biblionumber     = biblio.biblionumber
         LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
            WHERE issues.borrowernumber  = ?
            AND   issues.date_due < NOW()"
    );
    $sth->execute($borrowernumber);
    my $results = $sth->fetchall_arrayref({});
    return ( scalar(@$results), $results);  # returning the count and the results is silly
}

=head2 CalcFine

    ($amount, $units_minus_grace, $chargeable_units) = &CalcFine($item,
                                  $categorycode, $branch,
                                  $start_dt, $end_dt );

Calculates the fine for a book.

The issuingrules table in the Koha database is a fine matrix, listing
the penalties for each type of patron for each type of item and each branch (e.g., the
standard fine for books might be $0.50, but $1.50 for DVDs, or staff
members might get a longer grace period between the first and second
reminders that a book is overdue).


C<$item> is an item object (hashref).

C<$categorycode> is the category code (string) of the patron who currently has
the book.

C<$branchcode> is the library (string) whose issuingrules govern this transaction.

C<$start_date> & C<$end_date> are DateTime objects
defining the date range over which to determine the fine.

Fines scripts should just supply the date range over which to calculate the fine.

C<&CalcFine> returns three values:

C<$amount> is the fine owed by the patron (see above).

C<$units_minus_grace> is the number of chargeable units minus the grace period

C<$chargeable_units> is the number of chargeable units (days between start and end dates, Calendar adjusted where needed,
minus any applicable grace period, or hours)

FIXME: previously attempted to return C<$message> as a text message, either "First Notice", "Second Notice",
or "Final Notice".  But CalcFine never defined any value.

=cut

sub CalcFine {
    my ( $item, $bortype, $branchcode, $due_dt, $end_date  ) = @_;

    # Skip calculations if item is not overdue
    return ( 0, 0, 0 ) unless (DateTime->compare( $due_dt, $end_date ) == -1);

    my $start_date = $due_dt->clone();
    # get issuingrules (fines part will be used)
    my $itemtype = $item->{itemtype} || $item->{itype};
    my $issuing_rule = Koha::CirculationRules->get_effective_rules(
        {
            categorycode => $bortype,
            itemtype     => $itemtype,
            branchcode   => $branchcode,
            rules => [
                'lengthunit',
                'firstremind',
                'chargeperiod',
                'chargeperiod_charge_at',
                'fine',
                'overduefinescap',
                'cap_fine_to_replacement_price',
                'recall_overdue_fine',
            ]
        }
    );

    $itemtype = Koha::ItemTypes->find($itemtype);

    return unless $issuing_rule; # If not rule exist, there is no fine

    my $fine_unit = $issuing_rule->{lengthunit} || 'days';

    my $chargeable_units = get_chargeable_units($fine_unit, $start_date, $end_date, $branchcode);
    my $units_minus_grace = $chargeable_units - ($issuing_rule->{firstremind} || 0);
    my $amount = 0;
    if ( $issuing_rule->{chargeperiod} && ( $units_minus_grace > 0 ) ) {
        my $units = C4::Context->preference('FinesIncludeGracePeriod') ? $chargeable_units : $units_minus_grace;
        my $charge_periods = $units / $issuing_rule->{chargeperiod};
        # If chargeperiod_charge_at = 1, we charge a fine at the start of each charge period
        # if chargeperiod_charge_at = 0, we charge at the end of each charge period
        $charge_periods = defined $issuing_rule->{chargeperiod_charge_at} && $issuing_rule->{chargeperiod_charge_at} == 1 ? ceil($charge_periods) : floor($charge_periods);

        # check if item has been recalled. recall should have been marked Overdue by cronjob, so only look at overdue recalls
        # only charge using recall_overdue_fine if there is an item-level recall for this particular item, OR a biblio-level recall
        my @recalls = Koha::Recalls->search({ biblio_id => $item->{biblionumber}, status => 'overdue' })->as_list;
        my $bib_level_recall = 0;
        $bib_level_recall = 1 if scalar @recalls > 0;
        foreach my $recall ( @recalls ) {
            if ( $recall->item_level and $recall->item_id == $item->{itemnumber} and $issuing_rule->{recall_overdue_fine} ) {
                $bib_level_recall = 0;
                $amount = $charge_periods * $issuing_rule->{recall_overdue_fine};
                last;
            }
        }
        if ( $bib_level_recall and $issuing_rule->{recall_overdue_fine} ) {
            # biblio-level recall
            $amount = $charge_periods * $issuing_rule->{recall_overdue_fine};
        }
        if ( scalar @recalls == 0 && $issuing_rule->{fine}) {
            # no recall, use normal fine amount
            $amount = $charge_periods * $issuing_rule->{fine};
        }
    } # else { # a zero (or null) chargeperiod or negative units_minus_grace value means no charge. }

    $amount = $issuing_rule->{overduefinescap}
        if $issuing_rule->{overduefinescap}
        && $issuing_rule->{overduefinescap} > 0
        && $amount > $issuing_rule->{overduefinescap};

    # This must be moved to Koha::Item (see also similar code in C4::Accounts::chargelostitem
    $item->{replacementprice} ||= $itemtype->defaultreplacecost
      if $itemtype
      && ( ! defined $item->{replacementprice} || $item->{replacementprice} == 0 )
      && C4::Context->preference("useDefaultReplacementCost");

    $amount = $item->{replacementprice} if ( $issuing_rule->{cap_fine_to_replacement_price} && $item->{replacementprice} && $amount > $item->{replacementprice} );

    return ($amount, $units_minus_grace, $chargeable_units);
}


=head2 get_chargeable_units

    get_chargeable_units($unit, $start_date_ $end_date, $branchcode);

return integer value of units between C<$start_date> and C<$end_date>, factoring in holidays for C<$branchcode>.

C<$unit> is 'days' or 'hours' (default is 'days').

C<$start_date> and C<$end_date> are the two DateTimes to get the number of units between.

C<$branchcode> is the branch whose calendar to use for finding holidays.

=cut

sub get_chargeable_units {
    my ($unit, $date_due, $date_returned, $branchcode) = @_;

    # If the due date is later than the return date
    return 0 unless ( $date_returned > $date_due );

    my $charge_units = 0;
    my $charge_duration;
    if ($unit eq 'hours') {
        if(C4::Context->preference('finesCalendar') eq 'noFinesWhenClosed') {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            $charge_duration = $calendar->hours_between( $date_due, $date_returned );
        } else {
            $charge_duration = $date_returned->delta_ms( $date_due );
        }
        if($charge_duration->in_units('hours') == 0 && $charge_duration->in_units('seconds') > 0){
            return 1;
        }
        return $charge_duration->in_units('hours');
    }
    else { # days
        if(C4::Context->preference('finesCalendar') eq 'noFinesWhenClosed') {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            $charge_duration = $calendar->days_between( $date_due, $date_returned );
        } else {
            $charge_duration = $date_returned->delta_days( $date_due );
        }
        return $charge_duration->in_units('days');
    }
}


=head2 GetSpecialHolidays

    &GetSpecialHolidays($date_dues,$itemnumber);

return number of special days  between date of the day and date due

C<$date_dues> is the envisaged date of book return.

C<$itemnumber> is the book's item number.

=cut

sub GetSpecialHolidays {
    my ( $date_dues, $itemnumber ) = @_;

    # calcul the today date
    my $today = join "-", &Today();

    # return the holdingbranch
    my $iteminfo = GetIssuesIteminfo($itemnumber);

    # use sql request to find all date between date_due and today
    my $dbh = C4::Context->dbh;
    my $query =
      qq|SELECT DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') as date
FROM `special_holidays`
WHERE DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') >= ?
AND   DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') <= ?
AND branchcode=?
|;
    my @result = GetWdayFromItemnumber($itemnumber);
    my @result_date;
    my $wday;
    my $dateinsec;
    my $sth = $dbh->prepare($query);
    $sth->execute( $date_dues, $today, $iteminfo->{'branchcode'} )
      ;    # FIXME: just use NOW() in SQL instead of passing in $today

    while ( my $special_date = $sth->fetchrow_hashref ) {
        push( @result_date, $special_date );
    }

    my $specialdaycount = scalar(@result_date);

    for ( my $i = 0 ; $i < scalar(@result_date) ; $i++ ) {
        $dateinsec = UnixDate( $result_date[$i]->{'date'}, "%o" );
        ( undef, undef, undef, undef, undef, undef, $wday, undef, undef ) =
          localtime($dateinsec);
        for ( my $j = 0 ; $j < scalar(@result) ; $j++ ) {
            if ( $wday == ( $result[$j]->{'weekday'} ) ) {
                $specialdaycount--;
            }
        }
    }

    return $specialdaycount;
}

=head2 GetRepeatableHolidays

    &GetRepeatableHolidays($date_dues, $itemnumber, $difference,);

return number of day closed between date of the day and date due

C<$date_dues> is the envisaged date of book return.

C<$itemnumber> is item number.

C<$difference> numbers of between day date of the day and date due

=cut

sub GetRepeatableHolidays {
    my ( $date_dues, $itemnumber, $difference ) = @_;
    my $dateinsec = UnixDate( $date_dues, "%o" );
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($dateinsec);
    my @result = GetWdayFromItemnumber($itemnumber);
    my @dayclosedcount;
    my $j;

    for ( my $i = 0 ; $i < scalar(@result) ; $i++ ) {
        my $k = $wday;

        for ( $j = 0 ; $j < $difference ; $j++ ) {
            if ( $result[$i]->{'weekday'} == $k ) {
                push( @dayclosedcount, $k );
            }
            $k++;
            ( $k = 0 ) if ( $k eq 7 );
        }
    }
    return scalar(@dayclosedcount);
}


=head2 GetWayFromItemnumber

    &Getwdayfromitemnumber($itemnumber);

return the different week day from repeatable_holidays table

C<$itemnumber> is  item number.

=cut

sub GetWdayFromItemnumber {
    my ($itemnumber) = @_;
    my $iteminfo = GetIssuesIteminfo($itemnumber);
    my @result;
    my $query = qq|SELECT weekday
    FROM repeatable_holidays
    WHERE branchcode=?
|;
    my $sth = C4::Context->dbh->prepare($query);

    $sth->execute( $iteminfo->{'branchcode'} );
    while ( my $weekday = $sth->fetchrow_hashref ) {
        push( @result, $weekday );
    }
    return @result;
}


=head2 GetIssuesIteminfo

    &GetIssuesIteminfo($itemnumber);

return all data from issues about item

C<$itemnumber> is  item number.

=cut

sub GetIssuesIteminfo {
    my ($itemnumber) = @_;
    my $dbh          = C4::Context->dbh;
    my $query        = qq|SELECT *
    FROM issues
    WHERE itemnumber=?
    |;
    my $sth = $dbh->prepare($query);
    $sth->execute($itemnumber);
    my ($issuesinfo) = $sth->fetchrow_hashref;
    return $issuesinfo;
}


=head2 UpdateFine

    &UpdateFine(
        {
            issue_id       => $issue_id,
            itemnumber     => $itemnumber,
            borrowernumber => $borrowernumber,
            amount         => $amount,
            due            => $date_due
        }
    );

(Note: the following is mostly conjecture and guesswork.)

Updates the fine owed on an overdue book.

C<$itemnumber> is the book's item number.

C<$borrowernumber> is the borrower number of the patron who currently
has the book on loan.

C<$amount> is the current amount owed by the patron.

C<$due> is the date

C<&UpdateFine> looks up the amount currently owed on the given item
and sets it to C<$amount>, creating, if necessary, a new entry in the
accountlines table of the Koha database.

=cut

#
# Question: Why should the caller have to
# specify both the item number and the borrower number? A book can't
# be on loan to two different people, so the item number should be
# sufficient.
#
# Possible Answer: You might update a fine for a damaged item, *after* it is returned.
#
sub UpdateFine {
    my ($params) = @_;

    my $issue_id       = $params->{issue_id};
    my $itemnum        = $params->{itemnumber};
    my $borrowernumber = $params->{borrowernumber};
    my $amount         = $params->{amount};
    my $due            = $params->{due} // q{};

    unless ( $issue_id ) {
        carp("No issue_id passed in!");
        return;
    }

    my $dbh = C4::Context->dbh;
    my $overdues = Koha::Account::Lines->search(
        {
            borrowernumber    => $borrowernumber,
            debit_type_code   => 'OVERDUE'
        }
    );

    my $accountline;
    my $total_amount_other = 0.00;
    # Cycle through the fines and
    # - find line that relates to the requested $itemnum
    # - accumulate fines for other items
    # so we can update $itemnum fine taking in account fine caps
    while (my $overdue = $overdues->next) {
        if ( defined $overdue->issue_id && $overdue->issue_id == $issue_id && $overdue->status eq 'UNRETURNED' ) {
            if ($accountline) {
                Koha::Logger->get->debug("Not a unique accountlines record for issue_id $issue_id"); # FIXME Do we really need to log that?
                #FIXME Should we still count this one in total_amount ??
            }
            else {
                $accountline = $overdue;
            }
        }
        $total_amount_other += $overdue->amountoutstanding;
    }

    if ( my $maxfine = C4::Context->preference('MaxFine') ) {
        my $maxIncrease = $maxfine - $total_amount_other;
        return if Koha::Number::Price->new($maxIncrease)->round <= 0.00;
        if ($accountline) {
            if ( ( $amount - $accountline->amount ) > $maxIncrease ) {
                my $new_amount = $accountline->amount + $maxIncrease;
                Koha::Logger->get->debug("Reducing fine for item $itemnum borrower $borrowernumber from $amount to $new_amount - MaxFine reached");
                $amount = $new_amount;
            }
        }
        elsif ( $amount > $maxIncrease ) {
            Koha::Logger->get->debug("Reducing fine for item $itemnum borrower $borrowernumber from $amount to $maxIncrease - MaxFine reached");
            $amount = $maxIncrease;
        }
    }

    if ( $accountline ) {
        if ( Koha::Number::Price->new($accountline->amount)->round != Koha::Number::Price->new($amount)->round ) {
            $accountline->adjust(
                {
                    amount    => $amount,
                    type      => 'overdue_update',
                    interface => C4::Context->interface
                }
            );
        }
    } else {
        if ( $amount ) { # Don't add new fines with an amount of 0
            my $patron = Koha::Patrons->find( $borrowernumber );
            my $letter = eval { C4::Letters::GetPreparedLetter(
                module                 => 'circulation',
                letter_code            => 'OVERDUE_FINE_DESC',
                message_transport_type => 'print',
                lang                   => $patron->lang,
                tables                 => {
                    issues    => $itemnum,
                    borrowers => $borrowernumber,
                    items     => $itemnum,
                },
            ) };
            my $desc = $letter ? $letter->{content} : sprintf("Item %s - due %s", $itemnum, output_pref($due) );

            my $account = Koha::Account->new({ patron_id => $borrowernumber });
            $accountline = $account->add_debit(
                {
                    amount      => $amount,
                    description => $desc,
                    note        => undef,
                    user_id     => undef,
                    interface   => C4::Context->interface,
                    library_id  => undef, #FIXME: Should we grab the checkout or circ-control branch here perhaps?
                    type        => 'OVERDUE',
                    item_id     => $itemnum,
                    issue_id    => $issue_id,
                }
            );
        }
    }
}

=head2 GetFine

    $data->{'sum(amountoutstanding)'} = &GetFine($itemnum,$borrowernumber);

return the total of fine

C<$itemnum> is item number

C<$borrowernumber> is the borrowernumber

=cut 

sub GetFine {
    my ( $itemnum, $borrowernumber ) = @_;
    my $dbh   = C4::Context->dbh();
    my $query = q|SELECT sum(amountoutstanding) as fineamount FROM accountlines
    WHERE debit_type_code = 'OVERDUE'
  AND amountoutstanding > 0 AND borrowernumber=?|;
    my @query_param;
    push @query_param, $borrowernumber;
    if (defined $itemnum )
    {
        $query .= " AND itemnumber=?";
        push @query_param, $itemnum;
    }
    my $sth = $dbh->prepare($query);
    $sth->execute( @query_param );
    my $fine = $sth->fetchrow_hashref();
    if ($fine->{fineamount}) {
        return $fine->{fineamount};
    }
    return 0;
}

=head2 GetBranchcodesWithOverdueRules

    my @branchcodes = C4::Overdues::GetBranchcodesWithOverdueRules()

returns a list of branch codes for branches with overdue rules defined.

=cut

sub GetBranchcodesWithOverdueRules {
    my @branchcodes = Koha::CirculationRules->search(
        { rule_name => 'overdue_1_delay' },
        {
            order_by => 'branchcode',
            columns  => ['branchcode'],
            distinct => 1,
        }
    )->get_column('branchcode');
    if ( !$branchcodes[0] ) {
        @branchcodes = Koha::Libraries->search( {}, { order_by => 'branchname' } )->get_column('branchcode');
    }

    return @branchcodes;
}

=head2 GetOverduesForBranch

Sql request for display all information for branchoverdues.pl
2 possibilities : with or without location .
display is filtered by branch

FIXME: This function should be renamed.

=cut

sub GetOverduesForBranch {
    my ( $branch, $location) = @_;
	my $itype_link =  (C4::Context->preference('item-level_itypes')) ?  " items.itype " :  " biblioitems.itemtype ";
    my $dbh = C4::Context->dbh;
    my $select = "
    SELECT
            borrowers.cardnumber,
            borrowers.borrowernumber,
            borrowers.surname,
            borrowers.firstname,
            borrowers.phone,
            borrowers.email,
               biblio.title,
               biblio.subtitle,
               biblio.medium,
               biblio.part_number,
               biblio.part_name,
               biblio.author,
               biblio.biblionumber,
               issues.date_due,
               issues.returndate,
               issues.branchcode,
             branches.branchname,
                items.barcode,
                items.homebranch,
                items.itemcallnumber,
                items.location,
                items.itemnumber,
            itemtypes.description,
         accountlines.amountoutstanding
    FROM  accountlines
    LEFT JOIN issues      ON    issues.itemnumber     = accountlines.itemnumber
                          AND   issues.borrowernumber = accountlines.borrowernumber
    LEFT JOIN borrowers   ON borrowers.borrowernumber = accountlines.borrowernumber
    LEFT JOIN items       ON     items.itemnumber     = issues.itemnumber
    LEFT JOIN biblio      ON      biblio.biblionumber =  items.biblionumber
    LEFT JOIN biblioitems ON biblioitems.biblioitemnumber = items.biblioitemnumber
    LEFT JOIN itemtypes   ON itemtypes.itemtype       = $itype_link
    LEFT JOIN branches    ON  branches.branchcode     = issues.branchcode
    WHERE (accountlines.amountoutstanding  != '0.000000')
      AND (accountlines.debit_type_code     = 'OVERDUE' )
      AND (accountlines.status              = 'UNRETURNED' )
      AND (issues.branchcode =  ?   )
      AND (issues.date_due  < NOW())
    ";
    if ($location) {
        my $q = "$select AND items.location = ? ORDER BY borrowers.surname, borrowers.firstname";
        return @{ $dbh->selectall_arrayref($q, { Slice => {} }, $branch, $location ) };
    } else {
        my $q = "$select ORDER BY borrowers.surname, borrowers.firstname";
        return @{ $dbh->selectall_arrayref($q, { Slice => {} }, $branch ) };
    }
}

=head2 GetOverdueMessageTransportTypes

    my $message_transport_types = GetOverdueMessageTransportTypes( $branchcode, $categorycode, $letternumber);

    return a arrayref with all message_transport_type for given branchcode, categorycode and letternumber(1,2 or 3)

=cut

sub GetOverdueMessageTransportTypes {
    my ( $branchcode, $categorycode, $letternumber ) = @_;
    return unless $categorycode and $letternumber;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("
        SELECT message_transport_type
        FROM overduerules odr LEFT JOIN overduerules_transport_types ott USING (overduerules_id)
        WHERE branchcode = ?
          AND categorycode = ?
          AND letternumber = ?
    ");
    $sth->execute( $branchcode, $categorycode, $letternumber );
    my @mtts;
    while ( my $mtt = $sth->fetchrow ) {
        push @mtts, $mtt;
    }

    # Put 'print' in first if exists
    # It avoid to sent a print notice with an email or sms template is no email or sms is defined
    @mtts = uniq( 'print', @mtts )
        if grep { $_ eq 'print' } @mtts;

    return \@mtts;
}

=head2 parse_overdues_letter

parses the letter template, replacing the placeholders with data
specific to this patron, biblio, or item for overdues

named parameters:
  letter - required hashref
  borrowernumber - required integer
  substitute - optional hashref of other key/value pairs that should
    be substituted in the letter content

returns the C<letter> hashref, with the content updated to reflect the
substituted keys and values.

=cut

sub parse_overdues_letter {
    my $params = shift;
    foreach my $required (qw( letter_code borrowernumber )) {
        return unless ( exists $params->{$required} && $params->{$required} );
    }

    my $patron = Koha::Patrons->find( $params->{borrowernumber} );

    my $substitute = $params->{'substitute'} || {};

    my %tables = ( 'borrowers' => $params->{'borrowernumber'} );
    if ( my $p = $params->{'branchcode'} ) {
        $tables{'branches'} = $p;
    }

    my $active_currency = Koha::Acquisition::Currencies->get_active;

    my $currency_format;
    $currency_format = $active_currency->currency if defined($active_currency);

    my @item_tables;
    if ( my $i = $params->{'items'} ) {
        foreach my $item (@$i) {
            my $fine = GetFine($item->{'itemnumber'}, $params->{'borrowernumber'});
            $item->{'fine'} = currency_format($currency_format, "$fine", FMT_SYMBOL);
            # if active currency isn't correct ISO code fallback to sprintf
            $item->{'fine'} = sprintf('%.2f', $fine) unless $item->{'fine'};

            push @item_tables, {
                'biblio' => $item->{'biblionumber'},
                'biblioitems' => $item->{'biblionumber'},
                'items' => $item,
                'issues' => $item->{'itemnumber'},
            };
        }
    }

    return C4::Letters::GetPreparedLetter (
        module => 'circulation',
        letter_code => $params->{'letter_code'},
        branchcode => $params->{'branchcode'},
        lang => $patron->lang,
        tables => \%tables,
        loops => {
            overdues => [ map { $_->{items}->{itemnumber} } @item_tables ],
        },
        substitute => $substitute,
        repeat => { item => \@item_tables },
        message_transport_type => $params->{message_transport_type},
    );
}

1;
__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut
