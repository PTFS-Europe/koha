package Koha::ERM::UsageDataProvider;

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
use JSON qw( decode_json );
use LWP::UserAgent;
use Text::CSV_XS qw( csv );

use Koha::Exceptions;

use base qw(Koha::Object);

use Koha::ERM::CounterFile;
use Koha::ERM::CounterFiles;
use Koha::BackgroundJob::ErmSushiHarvester;

=head1 NAME

Koha::ERM::UsageDataProvider - Koha ErmUsageDataProvider Object class

=head1 API

=head2 Class Methods

=head3 counter_files

Getter/setter for counter_files for this usage data provider

=cut

sub counter_files {
    my ( $self, $counter_files ) = @_;

    if ($counter_files) {
        for my $counter_file (@$counter_files) {
            Koha::ERM::CounterFile->new($counter_file)
              ->store( $self->{job_callbacks} );
        }
    }
    my $counter_files_rs = $self->_result->erm_counter_files;
    return Koha::ERM::CounterFiles->_new_from_dbic($counter_files_rs);
}

=head3 run

Enqueues one harvest background job for each report type in this usage data provider

=cut

sub run {
    my ($self) = @_;

    my @report_types = split( /;/, $self->report_types );

    my @jobs;
    foreach my $report_type (@report_types) {

        my $job_id = Koha::BackgroundJob::ErmSushiHarvester->new->enqueue(
            {
                ud_provider_id => $self->erm_usage_data_provider_id,
                report_type    => $report_type
            }
        );

        push(
            @jobs,
            {
                report_type => $report_type,
                job_id      => $job_id
            }
        );
    }

    return \@jobs;
}

=head3 harvest

    $ud_provider->harvest(
        {
            step_callback        => sub { $self->step; },
            set_size_callback    => sub { $self->set_job_size(@_); },
            add_message_callback => sub { $self->add_message(@_); },
        }
    );

Run the SUSHI harvester of this usage data provider
Builds the URL query and requests the COUNTER 5 SUSHI service

COUNTER SUSHI api spec:
https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2

=over

=item report_type

Report type to run this harvest on

=back

=over

=item background_job_callbacks

Receive background_job_callbacks to be able to update job

=back

=cut

sub harvest {
    my ( $self, $report_type, $background_job_callbacks ) = @_;

    # Set class wide vars
    $self->{job_callbacks} = $background_job_callbacks;
    $self->{report_type} = $report_type;

    my $url      = $self->_build_url_query;
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

        #TODO: May want to add a job error message here?
        warn sprintf "ERROR - SUSHI service %s returned %s - %s\n", $url,
        $response->code, $message;
        if ( $response->code == 404 ) {
            Koha::Exceptions::ObjectNotFound->throw($message);
        }
        elsif ( $response->code == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        }
        else {
            #TODO: May want to add a job error message here?
            die sprintf "ERROR requesting SUSHI service\n%s\ncode %s: %s\n",
            $url, $response->code,
            $message;
        }
    }
    elsif ( $response->code == 204 ) {    # No content
        return;
    }

    # Parse the SUSHI response
    $self->parse_SUSHI_response( decode_json( $response->decoded_content ) );
}

=head3 parse_SUSHI_response

    $self->parse_SUSHI_response( decode_json( $response->decoded_content ) );

Parse the SUSHI response, prepare the COUNTER report file header,
column headings and body

=over

=item result

The result of the SUSHI response after json decoded

=back

=cut

sub parse_SUSHI_response {
    my ( $self, $result ) = @_;

    # Set class wide sushi response content
    $self->{sushi} = {
        header => $result->{Report_Header},
        body   => $result->{Report_Items}
    };

    # Get ready to build COUNTER file
    my @report_header          = $self->_COUNTER_report_header;
    my @report_column_headings = $self->_COUNTER_report_column_headings;
    my @report_body            = $self->_COUNTER_report_body;

    $self->_build_COUNTER_report_file( \@report_header,
        \@report_column_headings, \@report_body );
}

=head2 Internal methods

=head3 _build_url_query

Build the URL query params for COUNTER 5 SUSHI request

=cut

sub _build_url_query {
    my ($self) = @_;

    unless ( $self->service_url && $self->customer_id ) {
        die sprintf
"SUSHI Harvesting config for usage data provider %d is missing service_url or customer_id\n",
          $self->erm_usage_data_provider_id;
    }

    # FIXME: service_url needs to end in 'reports/'
    # below concat will result in a badly formed URL otherwise
    # Either validate this on UI form, here, or both
    my $url = $self->service_url;

    $url .= $self->{report_type};
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key           if $self->api_key;
    $url .= '&begin_date=' . $self->begin_date     if $self->begin_date;
    $url .= '&end_date=' . $self->end_date         if $self->end_date;

    return $url;
}

=head3 _build_COUNTER_report_file

Build the COUNTER file
https://cop5.projectcounter.org/en/5.0.2/03-specifications/02-formats-for-counter-reports.html#report-header

=cut

sub _build_COUNTER_report_file {
    my ( $self, $header, $column_headings, $body ) = @_;

    my @report = ( @{$header}, @{$column_headings}, @{$body} );

    #TODO: change this to tab instead of comma
    csv( in => \@report, out => \my $counter_file, encoding => "utf-8" );

    $self->counter_files(
        [
            {
                usage_data_provider_id => $self->erm_usage_data_provider_id,
                file_content           => $counter_file,
                date_uploaded => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),
                #TODO: add ".csv" to end of filename here
                filename => $self->name . "_" . $self->{report_type},
                type  =>  $self->{report_type}
            }
        ]
    );
}

=head3 _COUNTER_report_header

Return a COUNTER report header
https://cop5.projectcounter.org/en/5.0.2/04-reports/03-title-reports.html

=cut

sub _COUNTER_report_header {
    my ($self) = @_;

    my $header = $self->{sushi}->{header};

    my @metric_types_string =
      $self->_get_SUSHI_Name_Value( $header->{Report_Filters}, "Metric_Type" );

    my $begin_date =
      $self->_get_SUSHI_Name_Value( $header->{Report_Filters}, "Begin_Date" );
    my $end_date =
      $self->_get_SUSHI_Name_Value( $header->{Report_Filters}, "End_Date" );

    return (
        [ Report_Name      => $header->{Report_Name}      || "" ],
        [ Report_ID        => $header->{Report_ID}        || "" ],
        [ Release          => $header->{Release}          || "" ],
        [ Institution_Name => $header->{Institution_Name} || "" ],
        [
            Institution_ID => join(
                "; ",
                map( $_->{Type} . ":" . $_->{Value},
                    @{ $header->{Institution_ID} } )
              )
              || ""
        ],
        [
            Metric_Types => join( "; ", split( /\|/, $metric_types_string[0] ) )
              || ""
        ],
        [
            Report_Filters => join(
                "; ",
                map( $_->{Name} . ":" . $_->{Value},
                    @{ $header->{Report_Filters} } )
              )
              || ""
        ],

#TODO: Report_Attributes may need parsing, test this with a SUSHI response that provides it
        [ Report_Attributes => $header->{Report_Attributes} || "" ],
        [
            Exceptions => join(
                "; ",
                map( $_->{Code} . ": "
                      . $_->{Message} . " ("
                      . $_->{Data} . ")",
                    @{ $header->{Exceptions} } )
              )
              || ""
        ],
        [
                Reporting_Period => "Begin_Date="
              . $begin_date
              . "; End_Date="
              . $end_date
        ],
        [ Created    => $header->{Created}    || "" ],
        [ Created_By => $header->{Created_By} || "" ],
        [""]    #empty 13th line
    );
}

=head3 _COUNTER_title_report_row

Return a COUNTER title for the COUNTER titles report body
https://cop5.projectcounter.org/en/5.0.2/04-reports/03-title-reports.html#column-headings-elements

=cut

sub _COUNTER_title_report_row {
    my ( $self, $title_row, $metric_type ) = @_;

    my ( $total_usage, @monthly_usages ) =
      $self->_get_title_usages( $title_row, $metric_type );

    return (
        [
            $title_row->{Title}
              || "",
            $title_row->{Publisher}
              || "",
            $self->_get_SUSHI_Type_Value( $title_row->{Publisher_ID}, "ISNI" )
              || "",    #FIXME: this ISNI can't be right, can it?
            $title_row->{Platform}
              || "",
            $self->_get_SUSHI_Type_Value( $title_row->{Item_ID}, "DOI" )
              || "",
            $self->_get_SUSHI_Type_Value(
                $title_row->{Item_ID}, "Proprietary"
              )
              || "",
            $self->_get_SUSHI_Type_Value( $title_row->{Item_ID}, "Print_ISSN" )
              || "",
            $self->_get_SUSHI_Type_Value(
                $title_row->{Item_ID}, "Online_ISSN"
              )
              || "",
            "",    #FIXME: What goes in URI?
            $metric_type,
            $total_usage,
            @monthly_usages
        ]
    );
}

=head3 _get_title_usages

Returns the total and monthly usages for a title

=cut

sub _get_title_usages {
    my ( $self, $title, $metric_type ) = @_;

    my @usage_months = $self->_get_usage_months( $self->{sushi}->{header} );

    my @usage_months_fields = ();
    my $count_total         = 0;

    foreach my $usage_month (@usage_months) {
        my $month_is_empty = 1;

        foreach my $performance ( @{ $title->{Performance} } ) {
            my $period             = $performance->{Period};
            my $period_usage_month = substr( $period->{Begin_Date}, 0, 7 );

            my $instances = $performance->{Instance};
            my @metric_type_count =
              map( $_->{Metric_Type} eq $metric_type ? $_->{Count} : (),
                @{$instances} );

            if ( $period_usage_month eq $usage_month && $metric_type_count[0] ) {
                push( @usage_months_fields, $metric_type_count[0] );
                $count_total += $metric_type_count[0];
                $month_is_empty = 0;
            }
        }

        if ($month_is_empty) {
            push( @usage_months_fields, 0 );
        }
    }
    return ( $count_total, @usage_months_fields );
}

=head3 _COUNTER_report_body

Return the COUNTER report body as an array

=cut

sub _COUNTER_report_body {
    my ($self) = @_;

    my $header = $self->{sushi}->{header};
    my $body   = $self->{sushi}->{body};

    my @metric_types_string =
      $self->_get_SUSHI_Name_Value( $header->{Report_Filters}, "Metric_Type" );
    my @metric_types = split( /\|/, $metric_types_string[0] );

    my @report_body = ();

    # TODO: Platform report body

    # TODO: Database report body

    # Titles report body
    if ( $header->{Report_ID} =~ /TR/i ) {

        # Set job size to the amount of titles we're processing
        $self->{job_callbacks}->{set_size_callback}->( scalar( @{$body} ) );

        my $total_records = 0;
        foreach my $title_row ( @{$body} ) {

            # Add one title report row for each metric_type we're working with
            foreach my $metric_type (@metric_types) {
                push(
                    @report_body,
                    $self->_COUNTER_title_report_row(
                        $title_row, $metric_type
                    )
                );
            }
            $self->{counter_report} = { report_type => $self->{report_type}, total_records => ++$total_records };
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

=head3 _COUNTER_report_column_headings

Returns column headings by report type
  Check the report type from the COUNTER header
  and return column headings accordingly

=cut

sub _COUNTER_report_column_headings {
    my ($self) = @_;

    my $header = $self->{sushi}->{header};

    # TODO: Platform Report
    # TODO: Database Report

    # Titles Report
    if ( $header->{Report_ID} =~ /TR/i ) {
        return $self->_COUNTER_titles_report_column_headings;
    }

    # TODO: Item Report

    return;
}

=head3 _COUNTER_titles_report_column_headings

Return titles report column headings

=cut

sub _COUNTER_titles_report_column_headings {
    my ($self) = @_;

    my $header         = $self->{sushi}->{header};
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

            #TODO: What format is Reporting_Period_Total? example: "2020 total"
            "Reporting_Period_Total",

# @month_headings in "Mmm-yyyy" format. TODO: Show unless Exclude_Monthly_Details=true
            @month_headings
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
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
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

=head3 test_connection

Tests the connection of the harvester to the SUSHI service and returns any alerts of planned SUSHI outages

=cut

sub test_connection {
    my ($self) = @_;

    my $url = $self->service_url;
    $url .= '/status';
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key           if $self->api_key;


    my $request  = HTTP::Request->new( 'GET' => $url );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->simple_request($request);

    my @result = decode_json( $response->decoded_content );
    if($result[0][0]->{Service_Active}) {
        return 1
    } else {
        return 0
    }

}

=head3 _type

=cut

sub _type {
    return 'ErmUsageDataProvider';
}

1;
