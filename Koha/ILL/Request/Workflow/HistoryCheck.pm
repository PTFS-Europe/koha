package Koha::ILL::Request::Workflow::HistoryCheck;

# Copyright 2024 PTFS Europe Ltd
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

use Koha::I18N qw(__);

use base qw(Koha::ILL::Request::Workflow);

=head1 NAME

Koha::ILL::Request::HistoryCheck - Koha ILL HistoryCheck

=head1 SYNOPSIS

Object-oriented class that provides the ILL request type disclaimer

=head1 DESCRIPTION

This class provides the ability to verify if it should render type disclaimer
and handle the template params accordingly

=head1 API

=head2 Class Methods

=head3 show_history_check

    my $show_history_check =
    Koha::ILL::Request::HistoryCheck->show_history_check($params);

Given $params, return true if history check should be shown

=cut

sub show_history_check {
    my ( $self, $request ) = @_;

    return

        # ILLHistoryCheck is enabled
        C4::Context->yaml_preference("ILLHistoryCheck")

        # Matching requests were found
        && $self->_find_matching_requests()

        # History check has not yet been submitted
        && !$self->{metadata}->{history_check_submitted}

        # The form has been submitted and the backend is able to create the request
        && $request->_backend_capability( 'can_create_request', $self->{metadata} );
}

=head3 history_check_template_params

    my $history_check_template_params =
    Koha::ILL::Request::TypeDisclaimer->history_check_template_params(
        $params);

Given $params, return true if history check should be rendered

=cut

sub history_check_template_params {
    my ( $self, $params ) = @_;

    $params->{method} = 'historycheck' if $self->{ui_context} eq 'staff';
    delete $params->{stage}            if $self->{ui_context} eq 'staff';

    $params->{cardnumber} = C4::Context->userenv->{'cardnumber'} || 0 if $self->{ui_context} eq 'opac';

    my $backend = Koha::ILL::Request->new->load_backend( $params->{backend} );
    my $mapping_function;
    eval {
        $mapping_function = sub { return $backend->{_my_backend}->_get_core_fields()->{ $_[0] } };
        $backend->{_my_backend}->_get_core_fields();
    };
    if ($@) {
        $mapping_function = sub { return $_[0] };
    }

    my $matching_requests_for_patron = $self->_find_matching_requests();

    return (
        whole                        => $params,
        metadata                     => $self->prep_metadata($params),
        matching_requests_for_patron => $matching_requests_for_patron,
        $self->{ui_context} eq 'staff'
        ? (
            key_mapping        => $mapping_function,
            request_patron_obj => Koha::Patrons->find( { cardnumber => $params->{cardnumber} } )
            )
        : (),
        $self->{ui_context} eq 'opac'
        ? (
            illrequestsview => 1,
            message         => $params->{message},
            op              => 'historycheck',
            )
        : ()
    );
}

=head3 after_request_created

    $history_check->after_request_created($params, $request);

Actions that need to be done after the request has been created

=cut

sub after_request_created {
    my ( $self, $params, $request ) = @_;

    return if ( $self->{ui_context} ne 'opac' );

    my $patron_cardnumber = C4::Context->userenv->{'cardnumber'} || 0;
    my $matching_requests_for_patron = $self->_find_matching_requests();

    my $staffnotes;

    if ($matching_requests_for_patron) {
        my $appended_self_note = 0;
        foreach my $matching_request ( @{$matching_requests_for_patron} ) {
            next if $matching_request->illrequest_id eq $request->illrequest_id;
            if ( $appended_self_note == 0 ) {
                $staffnotes .= __("Request has been submitted by this patron in the past:");
                $appended_self_note = 1;
            }
            $staffnotes .= ' ' . $self->_get_request_staff_link($matching_request);
        }
    }

    $request->append_to_note($staffnotes)->store() if $staffnotes;
}

=head3 _get_request_staff_link

    $self->_get_request_staff_link($matching_request);

Returns an HTML staff link to the provided request

=cut

sub _get_request_staff_link {
    my ( $self, $request ) = @_;

    return
          '<a href="/cgi-bin/koha/ill/ill-requests.pl?op=illview&illrequest_id='
        . $request->illrequest_id . '">'
        . __("ILL Request #")
        . $request->illrequest_id . '</a>';
}

=head3 _find_matching_requests

    my $matching_requests = $self->_find_matching_requests();

Returns a list of matching requests (match is done by doi, issn, isbn, pubmedid)

=cut

sub _find_matching_requests {
    my ($self) = @_;

    my @id_fields = ( 'doi', 'issn', 'isbn', 'pubmedid' );

    my @existing_id_fields = grep { $self->{metadata}->{$_} } @id_fields;
    return 0 unless scalar @existing_id_fields;

    if (grep { $_ eq 'doi' } @existing_id_fields) {
        @existing_id_fields = grep { $_ eq 'doi' } @existing_id_fields;
    }

    if ( grep { $_ eq 'pubmedid' } @existing_id_fields ) {
        @existing_id_fields = grep { $_ eq 'pubmedid' } @existing_id_fields;
    }

    my $patron = Koha::Patrons->find( { cardnumber => $self->{metadata}->{cardnumber} } );

    my $query;
    $query->{'-and'} = [ { 'me.borrowernumber' => $patron->borrowernumber } ] if $patron;
    foreach my $id_field (@existing_id_fields) {
        push @{ $query->{'-or'} }, {
            'illrequestattributes.type'  => $id_field,
            'illrequestattributes.value' => $self->{metadata}->{$id_field},
        }
    }

    my $matching_requests = Koha::ILL::Requests->search(
        $query,
        {
            join     => 'illrequestattributes',
            distinct => 'illrequest_id',
        }
    );

    return $matching_requests->count ? $matching_requests->as_list : 0;
}

=head1 AUTHOR

Pedro Amorim <pedro.amorim@ptfs-europe.com>

=cut

1;
