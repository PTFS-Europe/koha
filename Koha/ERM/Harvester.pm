package Koha::ERM::Harvester;

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

use HTTP::Request;
use JSON qw( from_json decode_json encode_json );
use LWP::UserAgent;
use Text::CSV_XS qw( csv );

use Koha::Exceptions;

use base qw(Koha::Object);

use Koha::ERM::CounterFiles;

=head1 NAME

Koha::ERM::Harvester - Koha ErmHarvester Object class

=head1 API

=head2 Class Methods

=head3 counter_files

Getter/setter for counter_files for this harvester

=cut

sub counter_files {
    my ( $self, $counter_files ) = @_;

    if ($counter_files) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->counter_files->delete;

                for my $counter_file (@$counter_files) {
                    $self->_result->add_to_erm_counter_files($counter_file);
                }
            }
        );
    }
    my $counter_files_rs = $self->_result->erm_counter_files;
    return Koha::ERM::CounterFiles->_new_from_dbic($counter_files_rs);
}

=head3 run

Runs the harvest
* Builds the query and requests the COUNTER 5 SUSHI service
* Parses the report header, column headings and report body
* Add counter_files entry

* COUNTER SUSHI api spec:
https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2

=cut

sub run {
    my ($self) = @_;

    my $service_url = $self->service_url;

    my $url      = $self->_build_query();
    my $request  = HTTP::Request->new( 'GET' => $url );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->simple_request($request);

    if ( $response->code >= 400 ) {
        my $result = decode_json( $response->decoded_content );

        my $message;
        if ( ref($result) eq 'ARRAY' ) {
            for my $r (@$result) {
                $message .= $r->{message};
            }
        }
        else {
            #TODO: May want to check $result->{Report_Header}->{Exceptions} here
            $message = $result->{message} || $result->{Message} || q{};
            if ( $result->{errors} ) {
                for my $e ( @{ $result->{errors} } ) {
                    $message .= $e->{message};
                }
            }
        }
        warn sprintf "ERROR - SUSHI service %s returned %s - %s\n", $url,
          $response->code, $message;
        if ( $response->code == 404 ) {
            Koha::Exceptions::ObjectNotFound->throw($message);
        }
        elsif ( $response->code == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        }
        else {
            die sprintf "ERROR requesting SUSHI service\n%s\ncode %s: %s\n",
              $url, $response->code,
              $message;
        }
    }
    elsif ( $response->code == 204 ) {    # No content
        return;
    }

# $result is one of the following, depending on report_type:
# COUNTER_platform_report - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_platform_report
# COUNTER_database_report - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_database_report
# COUNTER_title_report - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_title_report
# COUNTER_item_report - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_item_report
    my $result = decode_json( $response->decoded_content );

# $header is a SUSHI_report_header model
# https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/SUSHI_report_header
    my $header        = $result->{Report_Header};
    my @report_header = $self->_COUNTER_report_header($header);

    # column headings
    my @column_headings = $self->_COUNTER_column_headings($header);

# $items is an array of one of the following, depending on report_type:
# COUNTER_platform_usage - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_platform_usage
# COUNTER_database_usage - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_database_usage
# COUNTER_title_usage - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_title_usage
# COUNTER_item_usage - https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2#/COUNTER_item_usage
    my $items       = $result->{Report_Items};
    my @report_body = $self->_COUNTER_report_body( $items, $header );

    $self->_build_COUNTER_file( \@report_header, \@column_headings,
        \@report_body );

# TODOs:
# error handle if server returns >= 400
# even if response code 200: check for Report_Header -> Exceptions -> Message (?)

    return 1;
}

=head2 Internal methods

=head3 _build_query

Build the URL query params for COUNTER 5 SUSHI request

=cut

sub _build_query {
    my ($self) = @_;

    unless ( $self->service_url && $self->customer_id ) {
        die sprintf "Harvester %d missing service_url or customer_id\n",
          $self->erm_harvester_id;
    }

    # FIXME: service_url needs to end in 'reports/'
    # below concat will result in a badly formed URL otherwise
    # Either validate this on UI form, here, or both
    my $url = $self->service_url;

    #FIXME: 'tr_j1' is supposed to be $self->report_type once that is done
    #TODO: a Harvester may have more than one report_type, separated by ";"
    $url .= 'tr_j1?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key if $self->api_key;

#FIXME: below date information should come from $self->begin_date and $self->end_date.
#Currently in the database these are set as harvest_start and harvest_end
    $url .= '&begin_date=2020-02';
    $url .= '&end_date=2023-04';

    return $url;
}

=head3 _build_COUNTER_file

Build the COUNTER file
https://cop5.projectcounter.org/en/5.0.2/03-specifications/02-formats-for-counter-reports.html#report-header

=cut

sub _build_COUNTER_file {
    my ( $self, $header, $column_headings, $body ) = @_;

    my @report = ( @{$header}, @{$column_headings}, @{$body} );

    #TODO: change this to tab instead of comma
    csv( in => \@report, out => \my $counter_file, encoding => "utf-8" );

    $self->counter_files(
        [
            {
                date          => "2022-01-01",
                file_content  => $counter_file,
                date_uploaded => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),

                #TODO: What should the filename be?
                filename => "filename.csv"
            }
        ]
    );

    #TODO: Add erm_counter_log database entry here or in CounterFile->new (?)
}

=head3 _COUNTER_report_header

Return a COUNTER report header
https://cop5.projectcounter.org/en/5.0.2/04-reports/03-title-reports.html

=cut

sub _COUNTER_report_header {
    my ( $self, $header ) = @_;

    return (
        [ Report_Name      => $header->{Report_Name}      || "" ],
        [ Report_ID        => $header->{Report_ID}        || "" ],
        [ Release          => $header->{Release}          || "" ],
        [ Institution_Name => $header->{Institution_Name} || "" ],

        #TODO: Institution_ID is array, needs parsing
        [ Institution_ID => $header->{Institution_ID} || "" ],
        [ Metric_Types   => $header->{Metric_Types}   || "" ],

        #TODO: Report_Filters is array, needs parsing
        [ Report_Filters => $header->{Report_Filters} || "" ],

        #TODO: Report_Attributes is array, needs parsing
        [ Report_Attributes => $header->{Report_Attributes} || "" ],

        #TODO: Exceptions is array, needs parsing
        [ Exceptions       => $header->{Exceptions}       || "" ],
        [ Reporting_Period => $header->{Reporting_Period} || "" ],
        [ Created          => $header->{Created}          || "" ],
        [ Created_By       => $header->{Created_By}       || "" ],
        [""]    #empty 13th line
    );
}

=head3 _COUNTER_title

Return a COUNTER title for the COUNTER titles report body
https://cop5.projectcounter.org/en/5.0.2/04-reports/03-title-reports.html#column-headings-elements

=cut

sub _COUNTER_title {
    my ( $self, $title, $metric_type, $usage_months ) = @_;

    my @usage_months_fields = ();
    my $count_total         = 0;

    foreach my $usage_month ( @{$usage_months} ) {
        my $month_is_empty = 1;

        foreach my $performance ( @{ $title->{Performance} } ) {
            my $period             = $performance->{Period};
            my $period_usage_month = substr( $period->{Begin_Date}, 0, 7 );

            my $instances = $performance->{Instance};
            my @metric_type_count =
              map( $_->{Metric_Type} eq $metric_type ? $_->{Count} : (),
                @{$instances} );

            if ( $period_usage_month eq $usage_month ) {
                push( @usage_months_fields, $metric_type_count[0] );
                $count_total += $metric_type_count[0];
                $month_is_empty = 0;
            }
        }

        if ($month_is_empty) {
            push( @usage_months_fields, 0 );
        }
    }

    return (
        [
            $title->{Title}
              || "",
            $title->{Publisher}
              || "",
            $self->_get_SUSHI_Type_Value( $title->{Publisher_ID}, "ISNI" )
              || "",    #FIXME: this ISNI can't be right, can it?
            $title->{Platform}
              || "",
            $self->_get_SUSHI_Type_Value( $title->{Item_ID}, "DOI" )
              || "",
            $self->_get_SUSHI_Type_Value( $title->{Item_ID}, "Proprietary" )
              || "",
            $self->_get_SUSHI_Type_Value( $title->{Item_ID}, "Print_ISSN" )
              || "",
            $self->_get_SUSHI_Type_Value( $title->{Item_ID}, "Online_ISSN" )
              || "",
            "",         #FIXME: What goes in URI?
            $metric_type,

#TODO: $count_total is only doing total for now, should it be doing total per year?
            $count_total,
            @usage_months_fields
        ]
    );

    #TODO: Add a erm_usage_titles database entry here
    #TODO: Add a erm_usage_mus database entry here
    #TODO: Add a erm_usage_yus database entry here
}

=head3 _COUNTER_report_body

Return the COUNTER report body as an array

=cut

sub _COUNTER_report_body {
    my ( $self, $body, $header ) = @_;

    my @usage_months = $self->_get_usage_months($header);
    my @metric_types_string =
      $self->_get_SUSHI_Name_Value( $header->{Report_Filters}, "Metric_Type" );
    my @metric_types = split( /\|/, $metric_types_string[0] );

    my @report_body = ();

    # TODO: Platform report body

    # TODO: Database report body

    # Titles report body
    if ( $header->{Report_ID} =~ /TR/i ) {
        foreach my $title ( @{$body} ) {

            # Add one title usage entry for each metric_type
            foreach my $metric_type (@metric_types) {
                push(
                    @report_body,
                    $self->_COUNTER_title(
                        $title, $metric_type, \@usage_months
                    )
                );
            }
        }
    }

    # TODO: Items report body

    return @report_body;
}

=head3 _get_SUSHI_Name_Value

Returns "Value" of a given "Name"

=cut

sub _get_SUSHI_Name_Value {
    my ( $self, $item, $name ) = @_;

    my @value = map( $_->{Name} eq $name ? $_->{Value} : (), @{$item} );

    return $value[0];
}

=head3 _get_SUSHI_Type_Value

Returns "Value" of a given "Type"

=cut

sub _get_SUSHI_Type_Value {
    my ( $self, $item, $type ) = @_;

    my @value = map( $_->{Type} eq $type ? $_->{Value} : (), @{$item} );

    return $value[0];
}

=head3 _COUNTER_column_headings

Returns column headings by report type

=cut

sub _COUNTER_column_headings {
    my ( $self, $header ) = @_;

    # TODO: Platform Report
    # TODO: Database Report

    # Titles Report
    if ( $header->{Report_ID} =~ /TR/i ) {
        return $self->_COUNTER_titles_report_column_headings($header);
    }

    # TODO: Item Report

    return;
}

=head3 _COUNTER_titles_report_column_headings

Return titles report column headings

=cut

sub _COUNTER_titles_report_column_headings {
    my ( $self, $header ) = @_;

    my @month_headings = $self->_get_usage_months( $header, 1 );

    return (
        [
            "Title",
            "Publisher",
            "Publisher_ID",
            "Platform",
            "DOI",
            "Proprietary_ID",

           #"ISBN", #TODO: Only if report_type does not contain insensitive tr_j
            "Print_ISSN",
            "Online_ISSN",
            "URI",

            #"Data_Type", #TODO: Only if requested (?)
            #"Section_Type", #TODO: Only if requested (?)
            #"YOP", #TODO: Only if requested (?)
            #"Access_Type", #TODO: Only if requested (?)
            #"Access_Method", #TODO: Only if requested (?)
            "Metric_Type",
            "Reporting_Period_Total"
            ,    #TODO: What format is this? example: "2020 total"
            @month_headings # Months in "Mmm-yyyy" format. Show unless Exclude_Monthly_Details=true
        ]
    );
}

=head3 _get_usage_months

Return report usage months. Formatted for column headings if $column_headings_formatting

=cut

sub _get_usage_months {
    my ( $self, $header, $column_headings_formatting ) = @_;

    my @months = (
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dez"
    );

    my @begin_date = map( $_->{Name} eq "Begin_Date" ? $_->{Value} : (),
        @{ $header->{Report_Filters} } );
    my $begin_month = substr( $begin_date[0], 5, 2 );
    my $begin_year  = substr( $begin_date[0], 0, 4 );

    my @end_date = map( $_->{Name} eq "End_Date" ? $_->{Value} : (),
        @{ $header->{Report_Filters} } );
    my $end_month = substr( $end_date[0], 5, 2 );
    my $end_year  = substr( $end_date[0], 0, 4 );

    my @month_headings = ();
    while ( $begin_month <= $end_month || $begin_year < $end_year ) {
        push( @month_headings,
              $column_headings_formatting
            ? $months[ $begin_month - 1 ] . " " . $begin_year
            : $begin_year . "-" . $begin_month );
        $begin_month++;
        if ( $begin_month > 12 ) {
            $begin_month = 1;
            $begin_year++;
        }
        $begin_month = "0" . $begin_month if length($begin_month) == 1;
    }

    return @month_headings;
}

=head3 _COUNTER_master_report

Returns the master report for a given report type
NOTE: Not being used at the moment, but could be useful later
https://www.projectcounter.org/code-of-practice-five-sections/3-0-technical-specifications/#reportsforlibraries

=cut

sub _COUNTER_master_report {
    my ( $self, $report_type ) = @_;

    #TODO: Below if/elsif could probably do better with regex instead
    if ( $report_type == "PR" || $report_type == "PR_P1" ) {
        return "PLATFORM";
    }
    elsif ($report_type == "DR"
        || $report_type == "DR_D1"
        || $report_type == "DR_D2" )
    {
        return "database";
    }
    elsif ($report_type == "TR"
        || $report_type == "TR_B1"
        || $report_type == "TR_B2"
        || $report_type == "TR_B3"
        || $report_type == "TR_J1"
        || $report_type == "TR_J2"
        || $report_type == "TR_J3"
        || $report_type == "TR_J4" )
    {
        return "title";
    }
    elsif ($report_type == "IR"
        || $report_type == "IR_A1"
        || $report_type == "IR_M1" )
    {
        return "item";
    }
}

## GENERAL COLUMN HEADINGS:
## Report Item Description, Platform, Report Item Identifiers, Parent Item, Component Item Description & IDs, Report/Item, Metric_Types, Usage

## TITLES COLUMN HEADINGS
# https://cop5.projectcounter.org/en/5.0.2/04-reports/03-title-reports.html

=head3 _type

=cut

sub _type {
    return 'ErmHarvester';
}

1;
