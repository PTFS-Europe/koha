#!/usr/bin/perl

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

use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use C4::Reports qw( GetDelimiterChoices );

use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Patron::Categories;

=head1 NAME

reports/borrowers_out.pl

=head1 DESCRIPTION

Plugin that shows a stats on borrowers

=cut

my $input = CGI->new;
my $do_it=$input->param('do_it');
my $fullreportname = "reports/borrowers_out.tt";
my $limit = $input->param("Limit");
my $column = $input->param("Criteria");
my @filters = $input->multi_param("Filter");
$filters[1] = eval { output_pref( { dt => dt_from_string( $filters[1]), dateonly => 1, dateformat => 'iso' } ); }
    if ( $filters[1] );

my $output = $input->param("output");
my $basename = $input->param("basename");
our $sep     = C4::Context->csv_delimiter(scalar $input->param("sep"));
my ($template, $borrowernumber, $cookie)
    = get_template_and_user({template_name => $fullreportname,
                query => $input,
                type => "intranet",
                flagsrequired => {reports => '*'},
                });
$template->param(do_it => $do_it,
        );
if ($do_it) {
# Displaying results
    my $results = calculate($limit, $column, \@filters);
    if ($output eq "screen"){
# Printing results to screen
        $template->param(mainloop => $results);
        output_html_with_http_headers $input, $cookie, $template->output;
        exit;
    } else {
# Printing to a csv file
        print $input->header(-type => 'application/vnd.sun.xml.calc',
                            -encoding    => 'utf-8',
                            -attachment=>"$basename.csv",
                            -filename=>"$basename.csv" );
        my $cols = @$results[0]->{loopcol};
        my $lines = @$results[0]->{looprow};
# header top-right
        print "num /". @$results[0]->{column} .$sep;
# Other header
        foreach my $col ( @$cols ) {
            print $col->{coltitle}.$sep;
        }
        print "Total\n";
# Table
        foreach my $line ( @$lines ) {
            my $x = $line->{loopcell};
            print $line->{rowtitle}.$sep;
            foreach my $cell (@$x) {
                my $cellvalue = defined $cell->{value} ? $cell->{value}.$sep : ''.$sep;
                print $cellvalue;
            }
#            print $line->{totalrow};
            print "\n";
        }
# footer
        print "TOTAL";
        $cols = @$results[0]->{loopfooter};
        foreach my $col ( @$cols ) {
            print $sep.$col->{totalcol};
        }
        print $sep.@$results[0]->{total};
        exit;
    }
# Displaying choices
} else {
    my $dbh = C4::Context->dbh;

    my $CGIextChoice = ( 'CSV' ); # FIXME translation
	my $CGIsepChoice = GetDelimiterChoices;

    my $patron_categories = Koha::Patron::Categories->search_with_library_limits({}, {order_by => ['categorycode']});
    $template->param(
                    CGIextChoice => $CGIextChoice,
                    CGIsepChoice => $CGIsepChoice,
                    patron_categories => $patron_categories,
                    );
output_html_with_http_headers $input, $cookie, $template->output;
}


sub calculate {
    my ($line, $column, $filters) = @_;
    my @mainloop;
    my @loopfooter;
    my @loopcol;
    my @looprow;
    my %globalline;
    my $grantotal =0;
# extract parameters
    my $dbh = C4::Context->dbh;

# Filters
# Checking filters
#
    my @loopfilter;
    for (my $i=0;$i<=2;$i++) {
        my %cell;
        if ( @$filters[$i] ) {
            if (($i==1) and (@$filters[$i-1])) {
                $cell{err} = 1 if (@$filters[$i]<@$filters[$i-1]) ;
            }
            $cell{filter} .= @$filters[$i];
            $cell{crit} .="Bor Cat" if ($i==0);
            $cell{crit} .="Without issues since" if ($i==1);
            push @loopfilter, \%cell;
        }
    }
    my $colfield;
    my $colorder;
    if ($column){
        $column = "borrowers.".$column if $column=~/categorycode/ || $column=~/branchcode/;
        my @colfilter ;
        $colfilter[0] = @$filters[0] if ($column =~ /category/ )  ;
    # 	$colfilter[0] = @$filters[11] if ($column =~ /sort2/ ) ;
    #warn "filtre col ".$colfilter[0]." ".$colfilter[1];
                                                
    # loop cols.
        $colfield .= $column;
        $colorder .= $column;
        
        my $strsth2;
        $strsth2 .= "select distinct " . $dbh->quote($colfield) . " FROM borrowers WHERE 1";
        my @query_args;
        if ( $colfilter[0] ) {
            $colfilter[0] =~ s/\*/%/g;
            $strsth2 .= " and " . $dbh->quote($column) . "LIKE ?" ;
            push @query_args, $colfilter[0];
        }
        $strsth2 .=" group by " . $dbh->quote($colfield);
        $strsth2 .=" order by " . $dbh->quote($colorder);
        # warn "". $strsth2;
        
        my $sth2 = $dbh->prepare( $strsth2 );
        $sth2->execute( @query_args );
        while (my ($celvalue) = $sth2->fetchrow) {
            my %cell;
    #		my %ft;
    #		warn "coltitle :".$celvalue;
            $cell{coltitle} = $celvalue;
    #		$ft{totalcol} = 0;
            push @loopcol, \%cell;
        }
    #	warn "fin des titres colonnes";
    }
    
    my $i=0;
#	my @totalcol;
    
    #Initialization of cell values.....
    my @table;
    
#	warn "init table";
    if($line) {
        for (my $i=1;$i<=$line;$i++) {
            foreach my $col ( @loopcol ) {
                $table[$i]->{($col->{coltitle})?$col->{coltitle}:"Global"}=0;
            }
        }
    }


# preparing calculation
    my $strcalc ;
    
# Processing calculation
    $strcalc .= "SELECT CONCAT( borrowers.surname , \"\\t\",borrowers.firstname, \"\\t\", borrowers.cardnumber)";
    $strcalc .= " , " . $dbh->quote($colfield) if ($colfield);
    $strcalc .= " FROM borrowers ";
    $strcalc .= "WHERE 1 ";
    my @query_args;
    if ( @$filters[0] ) {
        @$filters[0]=~ s/\*/%/g;
        $strcalc .= " AND borrowers.categorycode like ?";
        push @query_args, @$filters[0];
    }
    $strcalc .= " AND NOT EXISTS (SELECT * FROM issues WHERE issues.borrowernumber=borrowers.borrowernumber ";
    if ( @$filters[1] ) {
        $strcalc .= " AND issues.timestamp > ?";
        push @query_args, @$filters[1];
    }
    $strcalc .= ") ";
    $strcalc .= " AND NOT EXISTS (SELECT * FROM old_issues WHERE old_issues.borrowernumber=borrowers.borrowernumber ";
    if ( @$filters[1] ) {
        $strcalc .= " AND old_issues.timestamp > ?";
        push @query_args, @$filters[1];
    }
    $strcalc .= ") ";
    $strcalc .= " group by borrowers.borrowernumber";
    $strcalc .= ", " . $dbh->quote($colfield) if ($column);
    $strcalc .= " order by " . $dbh->quote($colfield) if ($colfield);
    my $max;
    if ($line) {
        if (@loopcol) {
            $max = $line*@loopcol;
        } else { $max=$line;}
        $strcalc .= " LIMIT 0,$max";
     } 
    
    my $dbcalc = $dbh->prepare($strcalc);
    $dbcalc->execute( @query_args );
# 	warn "filling table";
    my $previous_col;
    $i=1;
    while (my  @data = $dbcalc->fetchrow) {
        my ($row, $col )=@data;
        $col = "zzEMPTY" if (!defined($col));
        $i=1 if (($previous_col) and not($col eq $previous_col));
        $table[$i]->{$col}=$row;
#		warn " $i $col $row";
        $i++;
        $previous_col=$col;
    }
    
    push @loopcol,{coltitle => "Global"} if not($column);
    
    $max =(($line)?$line:@table -1);
    for ($i=1; $i<=$max;$i++) {
        my @loopcell;
        #@loopcol ensures the order for columns is common with column titles
        # and the number matches the number of columns
        my $colcount=0;
        foreach my $col ( @loopcol ) {
            my $value;
            if (@loopcol){
                $value =$table[$i]->{(($col->{coltitle} eq "NULL") or ($col->{coltitle} eq "Global"))?"zzEMPTY":$col->{coltitle}};
            } else {
                $value =$table[$i]->{"zzEMPTY"};
            }
            push @loopcell, {value => $value} ;
        }
        push @looprow,{ 'rowtitle' => $i ,
                        'loopcell' => \@loopcell,
                    };
    }
    
            

    # the header of the table
    $globalline{loopfilter}=\@loopfilter;
    # the core of the table
    $globalline{looprow} = \@looprow;
    $globalline{loopcol} = \@loopcol;
# 	# the foot (totals by borrower type)
    $globalline{loopfooter} = \@loopfooter;
    $globalline{total}= $grantotal;
    $globalline{line} = $line;
    $globalline{column} = $column;
    push @mainloop,\%globalline;
    return \@mainloop;
}

1;
__END__
