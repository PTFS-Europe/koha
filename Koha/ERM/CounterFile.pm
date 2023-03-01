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
use Koha::ERM::UsageDataProvider;

use base qw(Koha::Object);

use Koha::ERM::CounterLogs;

=head1 NAME

Koha::ERM::CounterFile - Koha ErmCounterFile Object class

=head1 API

=head2 Class Methods

=cut

=head3 counter_logs

Return the counter logs for this data provider

=cut

sub counter_logs {
    my ( $self ) = @_;
    my $counter_logs_rs = $self->_result->erm_counter_logs;
    return Koha::ERM::CounterLogs->_new_from_dbic($counter_logs_rs);
}

=head3 store

    $counter_file->store;

=cut

sub store {
    my $self = shift;

    my $result = $self->SUPER::store;

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

=head3 sub _add_usage_titles {

Goes through COUNTER file and adds usage_title for each row
#TODO: Yearly usage may be incorrect, it's only adding up the months in the current report, not necessarily the whole year

=cut

sub _add_usage_titles {
    my ($self) = @_;

    my $rows                = $self->_get_rows_from_COUNTER_file;
    my $usage_data_provider = $self->get_usage_data_provider;
    my $previous_title      = undef;
    my $usage_title         = undef;

    foreach my $row ( @{$rows} ) {

        # This is the same title, just a new row for a different metric_type
        if ( $previous_title && $previous_title->title eq $row->{Title} ) {
            $usage_title = $previous_title;
        }
        else {
            $usage_title = Koha::ERM::UsageTitle->new(
                {
                    title                  => $row->{Title},
                    usage_data_provider_id =>
                      $usage_data_provider->erm_usage_data_provider_id,
                    title_doi   => $row->{DOI},
                    print_issn  => $row->{Print_ISSN},
                    online_issn => $row->{Online_ISSN},
                    title_uri   => $row->{URI}
                }
            )->store;
        }

        # Regex match for Mmm-yyyy expected format, e.g. "Jan 2022"
        my @date_fields =
          map( $_ =~ /\b[A-Z][a-z][a-z]\b [0-9]{4}\b/ ? $_ : (), keys %{$row} );

        unless (@date_fields) {
            warn "No monthly usage fields retrieved";
        }

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

# TODO: Should we skip this monthly usage entry if title_id,metric_type,month,year already exists? To avoid duplicates

            # Skip this monthly usage entry if it's 0
            next if $usage eq "0";

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

        $self->_add_yearly_usage_entries( $usage_title, $row->{Metric_Type}, $usage_data_provider,
            \%yearly_usages, $self->type );

        $previous_title = $usage_title;
    }
}

=head3 _add_yearly_usage_entries

Adds erm_usage_yus database entries

=cut

sub _add_yearly_usage_entries {
    my ( $self, $usage_title, $metric_type, $usage_data_provider, $yearly_usages, $report_type ) = @_;

    while ( my ( $year, $usage ) = each( %{$yearly_usages} ) ) {

        next if $usage eq "0";

        $usage_title->yearly_usages(
            [
                {
                    title_id               => $usage_title->title_id,
                    usage_data_provider_id =>
                      $usage_data_provider->erm_usage_data_provider_id,
                    year       => $year,
                    totalcount => $usage,
                    metric_type => $metric_type,
                    report_type => $report_type
                }
            ]
        );
    }
}

=head3 sub _get_rows_from_COUNTER_file

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

=head3 sub _get_month_number

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
            borrowernumber         => undef,
            counter_files_id       => $self->erm_counter_files_id,
            importdate             => $self->date_uploaded,
            filename               => $self->filename,

    #TODO: add eventual exceptions coming from the COUNTER report to logdetails?
            logdetails => undef
        }
    )->store;
}

=head3 _type

=cut

sub _type {
    return 'ErmCounterFile';
}

1;
