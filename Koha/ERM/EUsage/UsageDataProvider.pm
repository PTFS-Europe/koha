package Koha::ERM::EUsage::UsageDataProvider;

# Copyright 2023 PTFS Europe

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

use Koha::Exceptions;

use base qw(Koha::Object);

use Koha::ERM::EUsage::CounterFile;
use Koha::ERM::EUsage::CounterFiles;
use Koha::ERM::EUsage::UsageTitles;
use Koha::ERM::EUsage::UsageItems;
use Koha::ERM::EUsage::UsagePlatforms;
use Koha::ERM::EUsage::UsageDatabases;
use Koha::ERM::EUsage::MonthlyUsages;
use Koha::ERM::EUsage::SushiCounter;
use Koha::BackgroundJob::ErmSushiHarvester;

=head1 NAME

Koha::ERM::EUsage::UsageDataProvider - Koha ErmUsageDataProvider Object class

=head1 API

=head2 Class Methods

=head3 counter_files

Getter/setter for counter_files for this usage data provider

=cut

sub counter_files {
    my ( $self, $counter_files ) = @_;

    if ($counter_files) {
        for my $counter_file (@$counter_files) {
            Koha::ERM::EUsage::CounterFile->new($counter_file)->store( $self->{job_callbacks} );
        }
    }
    my $counter_files_rs = $self->_result->erm_counter_files;
    return Koha::ERM::EUsage::CounterFiles->_new_from_dbic($counter_files_rs);
}

=head3 enqueue_counter_file_processing_job

Enqueues a background job to process a COUNTER file that has been uploaded

=cut

sub enqueue_counter_file_processing_job {
    my ( $self, $args ) = @_;

    my @jobs;
    my $job_id = Koha::BackgroundJob::ErmSushiHarvester->new->enqueue(
        {
            ud_provider_id => $self->erm_usage_data_provider_id,
            file_content   => $args->{file_content},
        }
    );

    push(
        @jobs,
        { job_id => $job_id }
    );

    return \@jobs;
}

=head3 enqueue_sushi_harvest_jobs

Enqueues one harvest background job for each report type in this usage data provider

=cut

sub enqueue_sushi_harvest_jobs {
    my ( $self, $args ) = @_;

    my @report_types = split( /;/, $self->report_types );

    my @jobs;
    foreach my $report_type (@report_types) {

        my $job_id = Koha::BackgroundJob::ErmSushiHarvester->new->enqueue(
            {
                ud_provider_id   => $self->erm_usage_data_provider_id,
                report_type      => $report_type,
                begin_date       => $args->{begin_date},
                end_date         => $args->{end_date},
                ud_provider_name => $self->name,
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

=head3 harvest_sushi

    $ud_provider->harvest_sushi(
        {
            begin_date  => $args->{begin_date},
            end_date    => $args->{end_date},
            report_type => $args->{report_type}
        }
    );

Runs this usage data provider's SUSHI harvester
Builds the URL query and requests the COUNTER 5 SUSHI service

COUNTER SUSHI api spec:
https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2

=over

=item begin_date

Begin date of the SUSHI harvest

=back

=over

=item end_date

End date of the SUSHI harvest

=back

=over

=item report_type

Report type to run this harvest on

=back

=cut

sub harvest_sushi {
    my ( $self, $args ) = @_;

    # Set class wide vars
    $self->{report_type} = $args->{report_type};
    $self->{begin_date}  = $args->{begin_date};
    $self->{end_date}    = $args->{end_date};
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
        } else {

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
        } elsif ( $response->code == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        } else {

            #TODO: May want to add a job error message here?
            die sprintf "ERROR requesting SUSHI service\n%s\ncode %s: %s\n",
                $url, $response->code,
                $message;
        }
    } elsif ( $response->code == 204 ) {    # No content
        return;
    }

    my $decoded_response = decode_json( $response->decoded_content );

    return if $self->_sushi_errors($decoded_response);

    # Parse the SUSHI response
    my $sushi_counter = Koha::ERM::EUsage::SushiCounter->new( { response => $decoded_response } );
    my $counter_file  = $sushi_counter->get_COUNTER_from_SUSHI;

    return if $self->_counter_file_size_too_large($counter_file);

    $self->counter_files(
        [
            {
                usage_data_provider_id => $self->erm_usage_data_provider_id,
                file_content           => $counter_file,
                date_uploaded          => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),

                #TODO: add ".csv" to end of filename here
                filename => $self->name . "_" . $self->{report_type},
            }
        ]
    );

}

=head3 set_background_job_callbacks

    $self->set_background_job_callbacks($background_job_callbacks);

Sets the background job callbacks

=over

=item background_job_callbacks

Background job callbacks

=back

=cut

sub set_background_job_callbacks {
    my ( $self, $background_job_callbacks ) = @_;

    $self->{job_callbacks} = $background_job_callbacks;
}

=head3 test_connection

Tests the connection of the harvester to the SUSHI service and returns any alerts of planned SUSHI outages

=cut

sub test_connection {
    my ($self) = @_;

    my $url = _validate_url( $self->service_url, 'status' );
    $url .= 'status';
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key if $self->api_key;

    my $request  = HTTP::Request->new( 'GET' => $url );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->simple_request($request);

    if ( $response->{_rc} >= 400 ) {
        my $message = $response->{_msg};
        if ( $response->{_rc} == 404 ) {
            Koha::Exceptions::ObjectNotFound->throw($message);
        } elsif ( $response->{_rc} == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        } else {
            die sprintf "ERROR testing SUSHI service\n%s\ncode %s: %s\n",
                $url, $response->{_rc},
                $message;
        }
    }

    my $result = decode_json( $response->decoded_content );
    my $status;
    if ( ref($result) eq 'ARRAY' ) {
        for my $r (@$result) {
            $status = $r->{Service_Active};
        }
    } else {
        $status = $result->{Service_Active};
    }

    if ($status) {
        return 1;
    } else {
        return 0;
    }
}

=head3 erm_usage_titles

Method to embed erm_usage_titles to titles for report formatting

=cut

sub erm_usage_titles {
    my ($self) = @_;
    my $usage_title_rs = $self->_result->erm_usage_titles;
    return Koha::ERM::EUsage::UsageTitles->_new_from_dbic($usage_title_rs);
}

=head3 erm_usage_muses

Method to embed erm_usage_muses to titles for report formatting

=cut

sub erm_usage_muses {
    my ($self) = @_;
    my $usage_mus_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::EUsage::MonthlyUsages->_new_from_dbic($usage_mus_rs);
}

=head3 erm_usage_platforms

Method to embed erm_usage_platforms to platforms for report formatting

=cut

sub erm_usage_platforms {
    my ($self) = @_;
    my $usage_platform_rs = $self->_result->erm_usage_platforms;
    return Koha::ERM::EUsage::UsagePlatforms->_new_from_dbic($usage_platform_rs);
}

=head3 erm_usage_items

Method to embed erm_usage_items to items for report formatting

=cut

sub erm_usage_items {
    my ($self) = @_;
    my $usage_item_rs = $self->_result->erm_usage_items;
    return Koha::ERM::EUsage::UsageItems->_new_from_dbic($usage_item_rs);
}

=head3 erm_usage_databases

Method to embed erm_usage_databases to databases for report formatting

=cut

sub erm_usage_databases {
    my ($self) = @_;
    my $usage_database_rs = $self->_result->erm_usage_databases;
    return Koha::ERM::EUsage::UsageDatabases->_new_from_dbic($usage_database_rs);
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

    my $url = _validate_url( $self->service_url, 'harvest' );

    $url .= lc $self->{report_type};
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key if $self->api_key;
    $url .= '&begin_date=' . substr $self->{begin_date}, 0, 7 if $self->{begin_date};
    $url .= '&end_date=' . substr $self->{end_date}, 0, 7 if $self->{end_date};

    return $url;
}

=head3 _validate_url

Checks whether the url ends in a trailing "/" and adds one if not

my $url = _validate_url($url, 'harvest')

$caller is either the harvest_sushi function ("harvest") or the test_connection function ("status")

=cut

sub _validate_url {
    my ( $url, $caller ) = @_;

    if ( $caller eq 'harvest' ) {

        # Not all urls will end in "/" - add one so they are standardised
        $url = _check_trailing_character($url);

        # All SUSHI report requests should be to the "/reports" endpoint
        # Not all providers in the counter registry include this in their data so we need to check and add it
        my $reports_param = substr $url, -8;
        $url .= 'reports/' if $reports_param ne 'reports/';
    } else {
        $url = _check_trailing_character($url);
    }

    return $url;
}

=head3 _check_trailing_character

Checks whether a url string ends in a "/" before we concatenate further params to the end of the url

=cut

sub _check_trailing_character {
    my ($url) = @_;

    my $trailing_char = substr $url, -1;
    if ( $trailing_char ne '/' ) {
        $url .= '/';
    }

    return $url;
}

=head3 _sushi_errors

Checks and handles possible errors in the SUSHI response
Additionally, adds background job report message(s) if that is the case

=cut

sub _sushi_errors {
    my ( $self, $decoded_response ) = @_;

    if ( $decoded_response->{Severity} ) {
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type    => 'error',
                code    => $decoded_response->{Code},
                message => $decoded_response->{Severity} . ' - ' . $decoded_response->{Message},
            }
        ) if $self->{job_callbacks};
        return 1;
    }

    if ( $decoded_response->{Report_Header}->{Exceptions} ) {
        foreach my $exception ( @{ $decoded_response->{Report_Header}->{Exceptions} } ) {
            $self->{job_callbacks}->{add_message_callback}->(
                {
                    type    => 'error',
                    code    => $exception->{Code},
                    message => $exception->{Message} . ' - ' . $exception->{Data},
                }
            ) if $self->{job_callbacks};
        }
        return 1;
    }

    if ( scalar @{ $decoded_response->{Report_Items} } == 0 ) {
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type => 'error',
                code => 'no_items',
            }
        ) if $self->{job_callbacks};
        return 1;
    }

    return 0;
}

=head3 _counter_file_size_too_large

Checks whether a counter file size exceeds the size allowed by the database or not
Additionally, adds a background job report message if that is the case

=cut

sub _counter_file_size_too_large {
    my ( $self, $counter_file ) = @_;

    my $max_allowed_packet = C4::Context->dbh->selectrow_array(q{SELECT @@max_allowed_packet});
    if ( length($counter_file) > $max_allowed_packet ) {
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type    => 'error',
                code    => 'payload_too_large',
                message => $max_allowed_packet / 1024 / 1024,
            }
        ) if $self->{job_callbacks};
        return 1;
    }
    return 0;
}

=head3 _type

=cut

sub _type {
    return 'ErmUsageDataProvider';
}

1;
