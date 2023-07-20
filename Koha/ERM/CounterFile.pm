package Koha::ERM::CounterFile;

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

use Text::CSV_XS qw( csv );

use Koha::ERM::CounterLog;
use Koha::ERM::UsageTitle;
use Koha::ERM::UsageTitles;
use Koha::ERM::UsageDataProvider;
use Koha::Exceptions::ERM::CounterFile;

use base qw(Koha::Object);

use Koha::ERM::CounterLogs;

=head1 NAME

Koha::ERM::CounterFile - Koha ErmCounterFile Object class

=head1 API

=head2 Class Methods

=cut

=head3 counter_logs

Return the counter_logs for this counter_file

=cut

sub counter_logs {
    my ($self) = @_;

    my $counter_logs_rs = $self->_result->erm_counter_logs;
    return Koha::ERM::CounterLogs->_new_from_dbic($counter_logs_rs);
}

=head3 store

    Koha::ERM::CounterFile->new($counter_file)->store( $self->{job_callbacks} );

Stores the csv COUNTER file.
Adds usage titles from the file.
Adds the respective counter_log entry.

=over

=item background_job_callbacks

Receive background_job_callbacks to be able to update job progress

=back

=cut

sub store {
    my ( $self, $background_job_callbacks ) = @_;

    $self->_validate;
    $self->_set_report_type_from_file;

    my $result = $self->SUPER::store;

    # Set class wide background_job callbacks
    $self->{job_callbacks} = $background_job_callbacks;

    $self->_add_usage_titles;
    $self->_add_counter_log_entry;

    return $result;
}

=head3 get_usage_data_provider

Getter for the usage data provider of this counter_file

=cut

sub get_usage_data_provider {
    my ($self) = @_;

    my $usage_data_provider = $self->_result->usage_data_provider;
    return Koha::ERM::UsageDataProvider->_new_from_dbic($usage_data_provider);
}

=head2 Internal methods

=head3 _add_usage_titles

Goes through COUNTER file and adds usage_title for each row

#FIXME?: "Yearly" usage may be incorrect, it'll only add up the months in the current report, not necessarily the whole year

=cut

sub _add_usage_titles {
    my ($self) = @_;

    my $rows                = $self->_get_rows_from_COUNTER_file;
    my $usage_data_provider = $self->get_usage_data_provider;
    my $previous_title      = undef;
    my $usage_title         = undef;
    my $i                   = 0;

    foreach my $row ( @{$rows} ) {

# INFO: A single title has multiple rows in the COUNTER report, for each metric_type
# If we're on a row of a title that we've already gone through,
# use the same usage_title and add usage statistics for the different metric_type
        if ( $previous_title && $previous_title->title_doi eq $row->{DOI} ) {
            $usage_title = $previous_title;
        }
        else {
            # Update background job step
            $self->{job_callbacks}->{step_callback}->() if $self->{job_callbacks};

            # Check if title already exists in this data provider, e.g. from a previous harvest
            $usage_title = Koha::ERM::UsageTitles->search(
                {
                    title_doi              => $row->{DOI},
                    usage_data_provider_id =>
                      $usage_data_provider->erm_usage_data_provider_id
                }
            )->last;

            if ($usage_title) {
                # Title already exists, add job warning message and do nothing else
                $self->{job_callbacks}->{add_message_callback}->(
                    {
                        type  => 'warning',
                        code  => 'title_already_exists',
                        title => $row->{Title},
                    }
                ) if $self->{job_callbacks};
            }
            else {
                # Fresh title, create it
                $usage_title = $self->_add_usage_title_entry( $row,
                    $usage_data_provider->erm_usage_data_provider_id );

                # Title created, add job success message
                $self->{job_callbacks}->{add_message_callback}->(
                    {
                        type  => 'success',
                        code  => 'title_added',
                        title => $row->{Title},
                    }
                ) if $self->{job_callbacks};
            }
        }

        # Regex match for Mmm-yyyy expected format, e.g. "Jan 2022"
        my @date_fields =
          map( $_ =~ /\b[A-Z][a-z][a-z]\b [0-9]{4}\b/ ? $_ : (), keys %{$row} );

        unless (@date_fields) {
            warn "No monthly usage fields retrieved";
        }

        # Add monthly usage statistics for this title
        my %yearly_usages = ();
        foreach my $year_month (@date_fields) {
            my $usage = %{$row}{$year_month};

            # Skip this monthly usage entry if it's 0
            next if $usage eq "0";

            my $month = substr( $year_month, 0, 3 );
            my $year  = substr( $year_month, 4, 4 );

            if ( !exists $yearly_usages{$year} ) {
                $yearly_usages{$year} = $usage;
            }
            else {
                $yearly_usages{$year} += $usage;
            }

            $usage_title->monthly_usages(
                [
                    {
                        title_id               => $usage_title->title_id,
                        usage_data_provider_id =>
                          $usage_data_provider->erm_usage_data_provider_id,
                        year        => $year,
                        month       => $self->_get_month_number($month),
                        usage_count => $usage,
                        metric_type => $row->{Metric_Type},
                        report_type => $self->type
                    }
                ]
            );
        }

        # Add yearly usage statistics for this title
        $self->_add_yearly_usage_entries(
            $usage_title,         $row->{Metric_Type},
            $usage_data_provider, \%yearly_usages
        );

        $previous_title = $usage_title;
    }
}

=head3 _add_yearly_usage_entries

Adds erm_usage_yus database entries

=cut

sub _add_yearly_usage_entries {
    my ( $self, $usage_title, $metric_type, $usage_data_provider, $yearly_usages ) = @_;

    while ( my ( $year, $usage ) = each( %{$yearly_usages} ) ) {

        # Skip this yearly usage entry if it's 0
        next if $usage eq "0";

        $usage_title->yearly_usages(
            [
                {
                    title_id               => $usage_title->title_id,
                    usage_data_provider_id =>
                      $usage_data_provider->erm_usage_data_provider_id,
                    year        => $year,
                    totalcount  => $usage,
                    metric_type => $metric_type,
                    report_type => $self->type
                }
            ]
        );
    }
}

=head3 _validate

Verifies if the given file_content is a valid COUNTER file or not

A I <Koha::Exceptions::ERM::CounterFile> exception is thrown
    if the file is invalid .

=cut

sub _validate {
    my ($self) = @_;

    open my $fh, "<", \$self->file_content or die;
    my $csv = Text::CSV_XS->new( { binary => 1, always_quote => 1, eol => $/, decode_utf8 => 1 } );

    $csv->column_names(qw( header_key header_value ));
    my @header_rows = $csv->getline_hr_all( $fh, 0, 12 );
    my @header = $header_rows[0];

    my @release_row =  map( $_->{header_key} eq 'Release' ? $_ : (), @{ $header[0] } );
    my $release = $release_row[0];

    # TODO: Validate that there is an empty row between header and body

    Koha::Exceptions::ERM::CounterFile::UnsupportedRelease->throw
        if $release && $release->{header_value} != 5;

}

=head3 _set_report_type_from_file

Extracts Report_ID from file and sets report_type for this counter_file

=cut

sub _set_report_type_from_file {
    my ($self) = @_;

    open my $fh, "<", \$self->file_content or die;
    my $csv = Text::CSV_XS->new( { binary => 1, always_quote => 1, eol => $/, decode_utf8 => 1 } );

    $csv->column_names(qw( header_key header_value ));
    my @header_rows = $csv->getline_hr_all( $fh, 0, 12 );
    my @header      = $header_rows[0];

    my @report_id_row = map( $_->{header_key} eq 'Report_ID' ? $_ : (), @{ $header[0] } );
    my $report        = $report_id_row[0];

    $self->type( $report->{header_value} );
}

=head3 _get_rows_from_COUNTER_file

Returns array of rows from COUNTER file

=cut

sub _get_rows_from_COUNTER_file {
    my ($self) = @_;

    open my $fh, "<", \$self->file_content or die;
    my $csv = Text::CSV_XS->new( { binary => 1, always_quote => 1, eol => $/, decode_utf8 => 1 } );

    my $header_columns = $csv->getline_all( $fh, 13, 1 );
    $csv->column_names( @{$header_columns}[0] );

    # Get all rows from 14th onward
    return $csv->getline_hr_all($fh);
}

=head3 _get_month_number

Returns month number for a given Mmm month

=cut

sub _get_month_number {
    my ( $self, $month ) = @_;

    my %months = (
        "Jan" => 1,
        "Feb" => 2,
        "Mar" => 3,
        "Apr" => 4,
        "May" => 5,
        "Jun" => 6,
        "Jul" => 7,
        "Aug" => 8,
        "Sep" => 9,
        "Oct" => 10,
        "Nov" => 11,
        "Dec" => 12
    );

    return $months{$month};
}

=head3 _add_counter_log_entry

Adds a erm_counter_logs database entry

=cut

sub _add_counter_log_entry {
    my ($self) = @_;

    Koha::ERM::CounterLog->new(
        {
#TODO: borrowernumber only required for manual uploads, maybe also for "harvest now" button clicks?
            borrowernumber   => undef,
            counter_files_id => $self->erm_counter_files_id,
            importdate       => $self->date_uploaded,
            filename         => $self->filename,

    #TODO: add eventual exceptions coming from the COUNTER report to logdetails?
            logdetails => undef
        }
    )->store;
}


=head3 _add_usage_title_entry

Adds a erm_usage_title database entry

=cut

sub _add_usage_title_entry {
    my ( $self, $row, $ud_provider_id ) = @_;

    return Koha::ERM::UsageTitle->new(
        {
            title                  => $row->{Title},
            usage_data_provider_id => $ud_provider_id,
            title_doi              => $row->{DOI},
            print_issn             => $row->{Print_ISSN},
            online_issn            => $row->{Online_ISSN},
            title_uri              => $row->{URI},
            publisher              => $row->{Publisher},
            publisher_id           => $row->{Publisher_ID},
        }
    )->store;
}

=head3 _type

=cut

sub _type {
    return 'ErmCounterFile';
}

1;
