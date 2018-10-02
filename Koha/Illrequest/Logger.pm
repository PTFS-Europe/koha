package Koha::Illrequest::Logger;

# Copyright 2018 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use JSON qw( to_json from_json );

use C4::Context;
use C4::Templates;
use C4::Log qw( logaction GetLogs );

=head1 NAME

Koha::Illrequest::Logger - Koha ILL Action / Event logger

=head1 SYNOPSIS

Object-oriented class that provides event logging functionality for
ILL requests

=head1 DESCRIPTION

This class provides the ability to log arbitrary actions or events
relating to Illrequest to the action log.

=head1 API

=head2 Class Methods

=head3 new

    my $config = Koha::Illrequest::Logger->new();

Create a new Koha::Illrequest::Logger object, with skeleton logging data
We also set up data of what can be logged, how to do it and how to display
log entries we get back out

=cut

sub new {
    my ( $class ) = @_;
    my $self  = {};

    $self->{data} = {
        modulename => 'ILL'
    };

    $self->{loggers} = {
        status => sub {
            $self->log_status_change(@_);
        }
    };

    my ( $htdocs, $theme, $lang, $base ) =
        C4::Templates::_get_template_file('ill/log/', 'intranet');

    $self->{templates} = {
        STATUS_CHANGE => $base . 'status_change.tt'
    };

    bless $self, $class;

    return $self;
}

=head3 log_maybe

    Koha::IllRequest::Logger->log_maybe($attrs);

Receive request object and an attributes hashref (which may or may
not be defined) If the hashref contains a key matching our "loggers" hashref
then we want to log it

=cut

sub log_maybe {
    my ($self, $req, $attrs) = @_;

    if (defined $req && defined $attrs) {
        foreach my $key (keys %{ $attrs }) {
            if (defined($self->{loggers}->{$key})) {
                $self->{loggers}->{$key}($req, $attrs->{$key});
            }
        }
    }
}

=head3 log_status_change

    Koha::IllRequest::Logger->log_status_change();

Log a request's status change

=cut

sub log_status_change {
    my ( $self, $req, $new_status ) = @_;

    $self->set_data({
        actionname   => 'STATUS_CHANGE',
        objectnumber => $req->id,
        infos        => to_json({
            log_origin    => 'core',
            status_before => $req->{previous_status},
            status_after  => $new_status
        })
    });

    $self->log_something();
}

=head3 log_something

    Koha::IllRequest::Logger->log_something();

If we have the required data set, log an action

=cut

sub log_something {
    my ( $self ) = @_;

    if (
        defined $self->{data}->{modulename} &&
        defined $self->{data}->{actionname} &&
        defined $self->{data}->{objectnumber} &&
        defined $self->{data}->{infos} &&
        C4::Context->preference("IllLog")
    ) {
        logaction(
            $self->{data}->{modulename},
            $self->{data}->{actionname},
            $self->{data}->{objectnumber},
            $self->{data}->{infos}
        );
    }
}

=head3 set_data

    Koha::IllRequest::Logger->set_data({
        key  => 'value',
        key2 => 'value2'
    });

Set arbitrary data propert(ies) on the logger object

=cut

sub set_data {
    my ( $self, $data ) = @_;

    foreach my $key (keys %{ $data }) {
        $self->{data}->{$key} = $data->{$key};
    }
}

=head3 get_log_template

    $template_path = get_log_template($origin, $action);

Given a log's origin and action, get the appropriate display template

=cut

sub get_log_template {
    my ($self, $req, $params) = @_;

    my $origin = $params->{origin};
    my $action = $params->{action};

    if ($origin eq 'core') {
        # It's a core log, so we can just get the template path from
        # the hashref above
        return $self->{templates}->{$action};
    } else {
        # It's probably a backend log, so we need to get the path to the
        # template from the backend
        my $backend =$req->{_my_backend};
        return $backend->get_log_template_path($action);
    }
}

=head3 get_request_logs

    $requestlogs = Koha::IllRequest::Logger->get_request_logs($request_id);

Get all logged actions for a given request

=cut

sub get_request_logs {
    my ( $self, $request ) = @_;

    my $logs = GetLogs(
        undef,
        undef,
        undef,
        ['ILL'],
        undef,
        $request->id,
        undef,
        undef
    );
    foreach my $log(@{$logs}) {
        $log->{info} = from_json($log->{info});
        $log->{template} = $self->get_log_template(
        $request,
            {
                origin => $log->{info}->{log_origin},
                action => $log->{action}
            }
        );
    }

    my @sorted = sort {$$b{'timestamp'} <=> $$a{'timestamp'}} @{$logs};

    return \@sorted;
}

=head1 AUTHOR

Andrew Isherwood <andrew.isherwood@ptfs-europe.com>

=cut

1;
