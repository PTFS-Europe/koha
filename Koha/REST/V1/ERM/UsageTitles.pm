package Koha::REST::V1::ERM::UsageTitles;

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
use Koha::ERM::UsageDataProvider;
use Koha::ERM::UsageDataProviders;

use Clone qw( clone );
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );
use JSON;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $usage_titles_set = Koha::ERM::UsageTitles->new;
        my $usage_titles = $c->objects->search( $usage_titles_set );
        return $c->render( status => 200, openapi => $usage_titles );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::ERM::UsageTitle object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $usage_title_id = $c->validation->param('erm_usage_title_id');
        my $usage_title    = $c->objects->find( Koha::ERM::UsageTitles->search, $usage_title_id );

        unless ($usage_title) {
            return $c->render(
                status  => 404,
                openapi => { error => "Usage title not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $usage_title
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::ERM::UsageTitle object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                my $usage_title = Koha::ERM::UsageTitle->new_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $usage_title->title_id);
                return $c->render(
                    status  => 201,
                    openapi => $usage_title->to_api
                );
            }
        );
    }
    catch {

        my $to_api_mapping = Koha::ERM::UsageTitle->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => $_->error, conflict => $_->duplicate_id }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->broken_fk }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->parameter }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::ERM::UsageTitle object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $usage_title_id = $c->validation->param('erm_usage_title_id');
    my $usage_title = Koha::ERM::UsageTitles->find( $usage_title_id );

    unless ($usage_title) {
        return $c->render(
            status  => 404,
            openapi => { error => "Usage title not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                $usage_title->set_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $usage_title->title_id);
                return $c->render(
                    status  => 200,
                    openapi => $usage_title->to_api
                );
            }
        );
    }
    catch {
        my $to_api_mapping = Koha::ERM::UsageTitle->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->broken_fk }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->parameter }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
};

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $usage_title_id = $c->validation->param('erm_usage_title_id');
    my $usage_title = Koha::ERM::UsageTitles->find( $usage_title_id );
    unless ($usage_title) {
        return $c->render(
            status  => 404,
            openapi => { error => "Usage title not found" }
        );
    }

    return try {
        $usage_title->delete;
        return $c->render(
            status  => 204,
            openapi => q{}
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 monthly_report

An endpoint to fetch filtered monthly report data for ERM usage statistics

=cut

sub monthly_report {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $args = $c->validation->output;

        my $usage_titles_set = Koha::ERM::UsageTitles->new;
        my $usage_titles = $c->objects->search( $usage_titles_set );

        my $usage_data_providers = Koha::ERM::UsageDataProviders->search({}, {})->unblessed;

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        my $metric_types = $query_params_array[0][0]->{'erm_usage_muses.metric_type'};

        # Titles with no data in the selected range will not be returned by the API - we still want to include them if they have been requested
        my $title_ids = $query_params_array[0][0]->{'erm_usage_muses.title_id'};

        for my $title_id (@{ $title_ids }) {
            my $check_title_exits = grep { $title_id eq $_->{title_id} } @{ $usage_titles };
            if(!$check_title_exits) {
                my $missing_usage_title = Koha::ERM::UsageTitles->find({ title_id => $title_id }, {})->unblessed;
                my @blank_statistics = ();

                my %missing_title_hash = (
                    usage_data_provider_id => $missing_usage_title->{usage_data_provider_id},
                    title_id => $missing_usage_title->{title_id},
                    title => $missing_usage_title->{title},
                    erm_usage_muses => \@blank_statistics,
                    online_issn => $missing_usage_title->{online_issn},
                    print_issn => $missing_usage_title->{print_issn},
                    title_doi => $missing_usage_title->{title_doi},
                    title_uri => $missing_usage_title->{title_uri},
                );

                push @{ $usage_titles }, \%missing_title_hash;
            }
        };

        my @title_report_data;

        for my $title ( @{ $usage_titles } ) {
            # Add provider name rather than embed provider object
            my $usage_data_provider_id = $title->{usage_data_provider_id};
            my @provider_object = grep { $usage_data_provider_id eq $_->{erm_usage_data_provider_id} } @{ $usage_data_providers };
            my $provider_name = $provider_object[0]->{name};
            $title->{provider_name} = $provider_name;

            # push @title_report_data, $title;

            # Split titles into metric_types i.e. one table row per metric_type
            for my $metric_type ( @$metric_types ) {
                my $statistics = $title->{'erm_usage_muses'};
                my @filtered_statistics = grep { $metric_type eq $_->{metric_type} } @$statistics;

                my %title_hash = (
                    usage_data_provider_id => $title->{usage_data_provider_id},
                    provider_name => $title->{provider_name},
                    title_id => $title->{title_id},
                    title => $title->{title},
                    erm_usage_muses => \@filtered_statistics,
                    online_issn => $title->{online_issn},
                    print_issn => $title->{print_issn},
                    title_doi => $title->{title_doi},
                    title_uri => $title->{title_uri},
                    metric_type => $metric_type,
                );

                push @title_report_data, \%title_hash;
            };
        };

        return $c->render( status => 200, openapi => \@title_report_data );
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

        my $usage_titles_set = Koha::ERM::UsageTitles->new;
        my $usage_titles = $c->objects->search( $usage_titles_set );

        my $usage_data_providers = Koha::ERM::UsageDataProviders->search({}, {})->unblessed;

        my @query_params_array;
        my $json = JSON->new;

        if ( ref( $args->{q} ) eq 'ARRAY' ) {
            foreach my $q ( @{ $args->{q} } ) {
                push @query_params_array, $json->decode($q)
                    if $q; 
            }
        }

        # Titles with no data in the selected range will not be returned by the API - we still want to include them if they have been requested
        my $title_ids = $query_params_array[0]->{'erm_usage_yuses.title_id'};

        for my $title_id (@{ $title_ids }) {
            my $check_title_exits = grep { $title_id eq $_->{title_id} } @{ $usage_titles };
            if(!$check_title_exits) {
                my $missing_usage_title = Koha::ERM::UsageTitles->find({ title_id => $title_id }, {})->unblessed;
                my @blank_statistics = ();

                my %missing_title_hash = (
                    usage_data_provider_id => $missing_usage_title->{usage_data_provider_id},
                    title_id => $missing_usage_title->{title_id},
                    title => $missing_usage_title->{title},
                    erm_usage_yuses => \@blank_statistics,
                    online_issn => $missing_usage_title->{online_issn},
                    print_issn => $missing_usage_title->{print_issn},
                    title_doi => $missing_usage_title->{title_doi},
                    title_uri => $missing_usage_title->{title_uri},
                );

                push @{ $usage_titles }, \%missing_title_hash;
            }
        };

        my $metric_types = $query_params_array[0]->{'erm_usage_yuses.metric_type'};

        my @title_report_data;

        for my $title ( @{ $usage_titles } ) {
            # Add provider name rather than embed provider object
            my $usage_data_provider_id = $title->{usage_data_provider_id};
            my @provider_object = grep { $usage_data_provider_id eq $_->{erm_usage_data_provider_id} } @{ $usage_data_providers };
            my $provider_name = $provider_object[0]->{name};
            $title->{provider_name} = $provider_name;

            # push @title_report_data, $title;

            # Split titles into metric_types i.e. one table row per metric_type
            for my $metric_type ( @$metric_types ) {
                my $statistics = $title->{'erm_usage_yuses'};
                my @filtered_statistics = grep { $metric_type eq $_->{metric_type} } @$statistics;

                my %title_hash = (
                    usage_data_provider_id => $title->{usage_data_provider_id},
                    provider_name => $title->{provider_name},
                    title_id => $title->{title_id},
                    title => $title->{title},
                    erm_usage_yuses => \@filtered_statistics,
                    online_issn => $title->{online_issn},
                    print_issn => $title->{print_issn},
                    title_doi => $title->{title_doi},
                    title_uri => $title->{title_uri},
                    metric_type => $metric_type,
                );

                push @title_report_data, \%title_hash;
            };
        };

        return $c->render( status => 200, openapi => \@title_report_data );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

1;
