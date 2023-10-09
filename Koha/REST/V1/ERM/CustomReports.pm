package Koha::REST::V1::ERM::CustomReports;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::ERM::UsageTitles;
use Koha::ERM::UsagePlatforms;
use Koha::ERM::UsageItems;
use Koha::ERM::UsageDatabases;
use Koha::ERM::UsageDataProvider;
use Koha::ERM::UsageDataProviders;

use Clone qw( clone );
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );
use JSON;

=head1 API

=head2 Methods

=head3 monthly_report

An endpoint to fetch filtered monthly report data for ERM usage statistics

=cut

sub monthly_report {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $args = $c->validation->output;

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        my $data_type = $c->validation->param('data_type');
        my $data_set = _get_data_set($data_type);
        my $data = $c->objects->search( $data_set );

        my $usage_data_providers = Koha::ERM::UsageDataProviders->search({}, {})->unblessed;
        my $metric_types = $query_params_array[0][0]->{'erm_usage_muses.metric_type'};

        # Objects with no data in the selected range will not be returned by the API - we still want to include them if they have been requested
        my $requested_ids = _get_correct_query_param($data_type, \@query_params_array, 'monthly');
        for my $id (@{ $requested_ids }) {
            my $missing_result = _get_result_with_no_statistics({
                data      => $data,
                data_type => $data_type,
                id        => $id,
            });
            push @{ $data }, $missing_result if $missing_result;
        };

        my @report_data;

        for my $data_object ( @{ $data } ) {
            # Add provider name rather than embed provider object
            my $usage_data_provider_id = $data_object->{usage_data_provider_id};
            my @provider_object = grep { $usage_data_provider_id eq $_->{erm_usage_data_provider_id} } @{ $usage_data_providers };
            my $provider_name = $provider_object[0]->{name};

            # Split data objects into metric_types i.e. one table row per metric_type
            for my $metric_type ( @$metric_types ) {
                my $statistics = $data_object->{'erm_usage_muses'};
                my @filtered_statistics = grep { $metric_type eq $_->{metric_type} } @$statistics;
                my @usage_counts = map { $_->{usage_count} } @filtered_statistics;
                my $sum = scalar(@usage_counts) > 0 ? eval join '+', @usage_counts : 0;

                my $data_object_hash = _get_object_hash({
                    data_type   => $data_type,
                    data_object => $data_object,
                    statistics  => \@filtered_statistics,
                    provider    => $provider_name,
                    metric_type => $metric_type,
                    period      => 'monthly',
                    sum         => $sum
                });

                push @report_data, $data_object_hash;
            };
        };

        return $c->render( status => 200, openapi => \@report_data );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 yearly_report

An endpoint to fetch filtered yearly report data for ERM usage statistics

=cut

sub yearly_report {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $args = $c->validation->output;

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        my $data_type = $c->validation->param('data_type');
        my $data_set = _get_data_set($data_type);
        my $data = $c->objects->search( $data_set );

        my $usage_data_providers = Koha::ERM::UsageDataProviders->search({}, {})->unblessed;


        # Titles with no data in the selected range will not be returned by the API - we still want to include them if they have been requested
        my $requested_ids = _get_correct_query_param($data_type, \@query_params_array, 'yearly');
        for my $id (@{ $requested_ids }) {
            my $missing_result = _get_result_with_no_statistics({
                data      => $data,
                data_type => $data_type,
                id        => $id,
            });
            push @{ $data }, $missing_result if $missing_result;
        };

        my $metric_types = $query_params_array[0]->{'erm_usage_yuses.metric_type'};
        my @report_data;

        for my $data_object ( @{ $data } ) {
            # Add provider name rather than embed provider object
            my $usage_data_provider_id = $data_object->{usage_data_provider_id};
            my @provider_object = grep { $usage_data_provider_id eq $_->{erm_usage_data_provider_id} } @{ $usage_data_providers };
            my $provider_name = $provider_object[0]->{name};

            # Split data objects into metric_types i.e. one table row per metric_type
            for my $metric_type ( @$metric_types ) {
                my $statistics = $data_object->{'erm_usage_yuses'};
                my @filtered_statistics = grep { $metric_type eq $_->{metric_type} } @$statistics;

                my $data_object_hash = _get_object_hash({
                    data_type   => $data_type,
                    data_object => $data_object,
                    statistics  => \@filtered_statistics,
                    provider    => $provider_name,
                    metric_type => $metric_type,
                    period      => 'yearly'
                });

                push @report_data, $data_object_hash;
            };
        };

        return $c->render( status => 200, openapi => \@report_data );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 metric_types_report

An endpoint to fetch report data for ERM usage statistics based on metric type columns

=cut

sub metric_types_report {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $args = $c->validation->output;

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        my $data_type = $c->validation->param('data_type');
        my $data_set = _get_data_set($data_type);
        my $data = $c->objects->search( $data_set );

        my $usage_data_providers = Koha::ERM::UsageDataProviders->search({}, {})->unblessed;

        # Objects with no data in the selected range will not be returned by the API - we still want to include them if they have been requested
        my $requested_ids = _get_correct_query_param($data_type, \@query_params_array, 'monthly');
        for my $id (@{ $requested_ids }) {
            my $missing_result = _get_result_with_no_statistics({
                data      => $data,
                data_type => $data_type,
                id        => $id,
            });
            push @{ $data }, $missing_result if $missing_result;
        };

        # my $metric_types = $query_params_array[0]->{'erm_usage_yuses.metric_type'};

        my @report_data;

        for my $data_object ( @{ $data } ) {
            # Add provider name rather than embed provider object
            my $usage_data_provider_id = $data_object->{usage_data_provider_id};
            my @provider_object = grep { $usage_data_provider_id eq $_->{erm_usage_data_provider_id} } @{ $usage_data_providers };
            my $provider_name = $provider_object[0]->{name};
            $data_object->{provider_name} = $provider_name;

            push @report_data, $data_object;
        };
        return $c->render( status => 200, openapi => \@report_data );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 provider_rollup_report

An endpoint to fetch all data for all providers for a given report type

=cut

sub provider_rollup_report {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $args = $c->validation->output;

        my $usage_data_providers_set = Koha::ERM::UsageDataProviders->new;
        my $usage_data_providers = $c->objects->search( $usage_data_providers_set );

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        my $data_type = $c->validation->param('data_type');
        my $key = 'erm_usage_' . $data_type . 's';
        my $metric_types = $query_params_array[0][0]->{$key . '.erm_usage_muses.metric_type'};

        my @usage_data_provider_report_data;

        for my $usage_data_provider ( @{ $usage_data_providers } ) {

            # Split usage_data_providers into metric_types i.e. one table row per metric_type
            for my $metric_type ( @$metric_types ) {
                my @filtered_object_data;

                for my $data_object ( @{ $usage_data_provider->{$key} }) {
                    my $statistics = $data_object->{'erm_usage_muses'};
                    my @filtered_statistics = grep { $metric_type eq $_->{metric_type} } @$statistics;
                    my @usage_counts = map { $_->{usage_count} } @filtered_statistics;
                    my $sum = scalar(@usage_counts) > 0 ? eval join '+', @usage_counts : 0;

                    my $data_object_hash = _get_object_hash({
                        data_type   => $data_type,
                        data_object => $data_object,
                        statistics  => \@filtered_statistics,
                        provider    => '',
                        metric_type => $metric_type,
                        period      => 'monthly',
                        sum         => $sum,
                    });

                    push @filtered_object_data, $data_object_hash;
                }

                my @data_object_usage_totals = map { $_->{usage_total} } @filtered_object_data;
                my $provider_rollup_total    = scalar(@data_object_usage_totals) > 0 ? eval join '+', @data_object_usage_totals : 0;

                my %usage_data_provider_hash = (
                    erm_usage_data_provider_id => $usage_data_provider->{erm_usage_data_provider_id},
                    aggregator                 => $usage_data_provider->{aggregator},
                    api_key                    => $usage_data_provider->{api_key},
                    begin_date                 => $usage_data_provider->{begin_date},
                    customer_id                => $usage_data_provider->{customer_id},
                    description                => $usage_data_provider->{description},
                    end_date                   => $usage_data_provider->{end_date},
                    method                     => $usage_data_provider->{method},
                    name                       => $usage_data_provider->{name},
                    report_release             => $usage_data_provider->{report_release},
                    report_types               => $usage_data_provider->{report_types},
                    requestor_email            => $usage_data_provider->{requestor_email},
                    requestor_id               => $usage_data_provider->{requestor_id},
                    requestor_name             => $usage_data_provider->{requestor_name},
                    service_type               => $usage_data_provider->{service_type},
                    service_url                => $usage_data_provider->{service_url},
                    metric_type                => $metric_type,
                    provider_rollup_total      => $provider_rollup_total,
                );
                $usage_data_provider_hash{$key} = \@filtered_object_data;

                push @usage_data_provider_report_data, \%usage_data_provider_hash;
            };
        };

        return $c->render( status => 200, openapi => \@usage_data_provider_report_data );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 _get_data_set

Returns the Koha object that needs to be used to fetch the data for this report.

=cut

sub _get_data_set {
    my ( $data_type ) = @_;

    if($data_type eq 'title') {
        return Koha::ERM::UsageTitles->new;
    }
    if($data_type eq 'platform') {
        return Koha::ERM::UsagePlatforms->new;
    }
    if($data_type eq 'item') {
        return Koha::ERM::UsageItems->new;
    }
    if($data_type eq 'database') {
        return Koha::ERM::UsageDatabases->new;
    }
    return 0;
}

=head3 _get_correct_query_param

Returns the array of ids (or an empty array) for the data type that has been requested as a report parameter.
e.g. If it is a titles report and the user has requested titles with the ids 1,2,3, these will be fetched from the query parameters and returned as (1,2,3).

=cut

sub _get_correct_query_param {
    my ( $data_type, $array_ref, $period ) = @_;

    my $param;
    my @query_params = @$array_ref;

    my $prefix = $period eq 'monthly' ? 'erm_usage_muses' : 'erm_usage_yuses';
    my $key = $prefix . "." . $data_type . "_id";

    if($period eq 'monthly') {
        $param = $query_params[0][0]->{$key};
    } else {
        $param = $query_params[0]->{$key};
    }

    return $param
}

=head3 _get_result_with_no_statistics

Takes in an id number and a dataset. If that id number exists within the dataset then no action is needed.
If it isn't found then that means there are no statistics for that object. It is however required in the report so is returned with a blank dataset.

=cut

sub _get_result_with_no_statistics {
    my ( $args ) = @_;

    my $data      = $args->{data};
    my $data_type = $args->{data_type};
    my $id        = $args->{id};
    my $identifier = $data_type . "_id";

    my $check_result = grep { $id eq $_->{$identifier} } @{ $data };
    if(!$check_result) {
        my $missing_result = _get_missing_data($data_type, $id);
        my @blank_statistics = ();
        return _get_object_hash({
            data_type   => $data_type,
            data_object => $missing_result,
            statistics  => \@blank_statistics,
            provider    => '',
            metric_type => '',
        });
    }
    return 0;
}

=head3 _get_object_hash

Returns a hash for a given data type with some additional parameters.

=cut

sub _get_object_hash {
    my ( $args ) = @_;

    my $data_type   = $args->{data_type};
    my $data_object = $args->{data_object};
    my $statistics  = $args->{statistics};
    my $provider    = $args->{provider};
    my $metric_type = $args->{metric_type};
    my $period      = $args->{period};
    my $sum         = $args->{sum};
    my %object_hash;

    if($data_type eq 'title') {
        %object_hash = (
            usage_data_provider_id => $data_object->{usage_data_provider_id},
            provider_name          => $provider,
            title_id               => $data_object->{title_id},
            title                  => $data_object->{title},
            online_issn            => $data_object->{online_issn},
            print_issn             => $data_object->{print_issn},
            title_doi              => $data_object->{title_doi},
            title_uri              => $data_object->{title_uri},
            publisher              => $data_object->{publisher},
            publisher_id           => $data_object->{publisher_id},
            metric_type            => $metric_type,
        );
    }
    if($data_type eq 'platform') {
        %object_hash = (
            usage_data_provider_id => $data_object->{usage_data_provider_id},
            provider_name          => $provider,
            metric_type            => $metric_type,
            platform               => $data_object->{platform},
            platform_id            => $data_object->{platform_id},
        );
    }
    if($data_type eq 'database') {
        %object_hash = (
            usage_data_provider_id => $data_object->{usage_data_provider_id},
            provider_name          => $provider,
            database_id            => $data_object->{database_id},
            database               => $data_object->{database},
            platform               => $data_object->{platform},
            publisher              => $data_object->{publisher},
            publisher_id           => $data_object->{publisher_id},
            metric_type            => $metric_type,
        );
    }
    if($data_type eq 'item') {
        %object_hash = (
            usage_data_provider_id => $data_object->{usage_data_provider_id},
            provider_name          => $provider,
            item_id                => $data_object->{item_id},
            item                   => $data_object->{item},
            platform               => $data_object->{platform},
            publisher              => $data_object->{publisher},
            publisher_id           => $data_object->{publisher_id},
            metric_type            => $metric_type,
        );
    }

    $object_hash{usage_total} = $sum if $sum;

    if($period eq 'yearly') {
        $object_hash{erm_usage_yuses} = $statistics;
    } else {
        $object_hash{erm_usage_muses} = $statistics;
    }
    return \%object_hash;
}

=head3 _get_missing_data

If an id is identified as missing, this piece of data is fetched and returned into _get_result_with_no_statistics for processing.

=cut

sub _get_missing_data {
    my ( $data_type, $id ) = @_;
    
    my $item;

    if($data_type eq 'title') {
        $item = Koha::ERM::UsageTitles->find({ title_id => $id }, {})->unblessed;
    }
    if($data_type eq 'platform') {
        $item = Koha::ERM::UsagePlatforms->find({ platform_id => $id }, {})->unblessed;
    }
    if($data_type eq 'database') {
        $item = Koha::ERM::UsageDatabases->find({ database_id => $id }, {})->unblessed;
    }
    if($data_type eq 'item') {
        $item = Koha::ERM::UsageItems->find({ item_id => $id }, {})->unblessed;
    }

    return $item if $item;
}

1;
