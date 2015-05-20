package Koha::Service::ILL;

# This file is part of Koha.
#
# Copyright 2007 LibLime
# Copyright 2012 software.coop and MJ Ray
# Copyright (C) 2014 ByWater Solutions
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

use base 'Koha::Service';

use Koha::Borrowers;
use Koha::Borrower::ILLRequest;
use Koha::ILLRequests;

use JSON;


my $illRequests = Koha::ILLRequests->new;

sub new {
    my ($class) = @_;

    return $class->SUPER::new(
        {
            needed_flags => {},
            routes       => [
                [ qr'GET /',      'search' ],
                [ qr'POST /',     'record' ],
                [ qr'PUT /(\d+)', 'update' ],
            ]
        }
    );
}

sub search {
    my ($self) = @_;
    my $reply = [];

    if ( $self->query->param('query') ) {
        my $query = $self->query->param('query');
        my $reply = $illRequests->search_api( { keywords => $query } );
        $self->output( $reply, { status => '200 OK', type => 'json' } );
    }
    elsif ( $self->query->param('borrowernumber') ) {
        my $borrowernumber = $self->query->param('borrowernumber');
        my $requests = $illRequests->search($borrowernumber);
        if ($requests) {
            foreach my $rq ( @{$requests} ) {
                push @{$reply}, $rq->getSummary();
            }

            $self->output( $reply, { status => '200 OK', type => 'json' } );
        }
        else {
            $self->output( { data => 'None found' },
                { status => '200 OK', type => 'json' } );
        }
    }
    else {
        $self->output();
    }
    return;
}

sub record {
    my ($self) = @_;

    my $result   = {};
    my $postdata = $self->query->param('POSTDATA');
    $postdata =

      my $illrequest = Koha::Borrower::ILLRequest->new('');
    return;
}

sub retrieve {
    my ($self) = @_;

    return;
}

sub update {
    my ($self) = @_;

    return;
}

sub delete {
    my ($self) = @_;

    return;
}

1;
