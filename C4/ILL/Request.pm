package C4::ILL::Request;
use strict;
use warnings;

# Copyright 2013,2014 PTFS Europe Ltd
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

use Carp;
use C4::Context;
use DBI;
our $VERSION = '1.00';

=head1 NAME

C4::ILL::Request

=head1 SYNOPSIS

use C4::ILL::Request;

my $req = C4::ILL::Request->new();
$req->retrieve()

methods of form set_x set values in the object in memory and require
a save to be stored in the db

methods in the form update_x set values and save them to the database

retrieve methods pull data from the database

=head1 METHODS

=head2 new

$req_obj C4::ILL::Request->new( {id => 42} )


Creates a new request object fields to be populated are specified in a hashref

=cut

sub new {
    my ( $class, %param ) = @_;
    my $self = \%param;

    bless $self, $class;
    return $self;
}

=head2 save

Writes the object to permanent store as a new request

=cut

sub save {
    my $self = shift;

    #if ($self->{id} { $self->update()
    my $sql = <<'END_INSERT';
    insert into illrequest
    ( borrowernumber, biblionumber, status, placement_date, reply_date,
        completion_date,  reqtype, branch)
    values ( ?, ?, ?, ?,?, ?, ?,?)
END_INSERT
    my $dbh = C4::Context->dbh;
    $dbh->do(
        $sql, {},
        $self->{borrowernumber}, $self->{biblionumber},
        $self->{status},         $self->{placement_date},
        $self->{reply_date},     $self->{completion_date},
        $self->{reqtype},        $self->{branch}
    );
    $self->{id} = $dbh->{mysql_insertid};
    my $sth = $dbh->prepare(
' INSERT INTO illreq_attribute ( req_id, type, value ) values ( ?, ?, ?)'
    );
    foreach my $a ( @{ $self->{attributes} } ) {
        $sth->execute( $self->{id}, $a->{type}, $a->{value} );
    }

    return;
}

=head2 retrieve

Populates the object's data members from the database requires that
the objects id was supplied on creation

=cut

sub retrieve {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        my $hashref =
          $dbh->selectrow_hashref( 'select * from illrequest where id = ?',
            {}, $self->{id} );
        if ($hashref) {    # clear fields
            $self = $hashref;
            $self->retrieve_attributes();
            return 1;
        }
    }
    return;
}

=head2 retrieve_attributes

Sets the member attributes to an arrayref of hash_refs containing
The attributes of the request from the database
iUsually called by other object methods rather than directly

=cut

sub retrieve_attributes {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        $self->{attributes} = $dbh->selectall_arrayref(
            'select * from illreq_attribute where req_id = ?' . { Slice => {} },
            $self->{id}
        );
    }
    else {
        $self->{attributes} = \();
    }
    return;
}

=head2 update

Update all fields for the request object

=cut

sub update {
    my $self = shift;
    my $sql  = <<'END_UPD';
      update illrequest
     set borrowernumber = ?, set biblionumber = ?, set status = ?,
     set placement_date = ?, set reply_date,
     set completion_date = ?, set  reqtype = ?, set branch = ?
     where id = ?
END_UPD
    my $dbh = C4::Context->dbh;
    $dbh->do(
        $sql, {},
        $self->{borrowernumber}, $self->{biblionumber},
        $self->{status},         $self->{placement_date},
        $self->{reply_date},     $self->{completion_date},
        $self->{reqtype},        $self->{branch},
        $self->{id}
    );
    return;
}

=head2 update_attributes

Update all attributes for the request

=cut

sub update_attributes {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare(
' INSERT INTO illreq_attribute ( req_id, type, value ) values ( ?, ?, ?)'
        );
        $dbh->begin_work;
        $dbh->do( 'delete from illreq_attribute where req_id = ?',
            {}, $self->{id} );
        foreach my $a ( @{ $self->{attributes} } ) {
            $sth->execute( $self->{id}, $a->{type}, $a->{value} );
        }
        $dbh->commit;
    }
    return;
}

=head2 update_status

Update the objects status and save to the database

=cut

sub update_status {
    my $self     = shift;
    my $newvalue = shift;

    $self->{status} = $newvalue;
    my $dbh = C4::Context->dbh;
    return $dbh->do( 'UPDATE illrequest set status = ? where id = ?',
        $self->{status}, $self->{id} );
}

=head2 set_attribute

Set an attribute value in the object

 $request->set_attribute('title', 'Tristram Shandy');

sets a single attribute in the object,
NB value is not saved to database
until a save operation is called on the object

=cut

sub set_attribute {
    my ($self, $attr_type, $attr_value) = @_;

    push @{$self->{attributes} }, {
        type  => $attr_type,
        value => $attr_value,
    };
    return;
}

=head2 delete

Delete a request and its attributes

=cut

sub delete {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        $dbh->do( 'delete from illreq_attribute where req_id = ?',
            {}, $self->{id} );
        return $dbh->do( 'delete from illrequest where id = ?', {},
            $self->{id} );
    }
    return;
}

=head2 get_resultset

C4::ILL::Request->get_resultset($type)

Class method returns an array_ref of C4::ILL::Request objects

$type may specify ALL NEW COMPLETED or OPENNOTNEW

=cut

sub get_resultset {
    my ( $class, $rs_type );
    my $dbh = C4::Context->dbh;
    my $cfg = C4::ILL::Config->new();
    my @bind_values;
    my $stmt = {
        ALL => 'select * from illrequest order by placement_date asc',
        NEW =>
          'select * from illrequest where status=? order by placement_date asc',
        COMPLETED =>
'select * from illrequest where completed_date is not null order by placement_date asc',
        OPENNOTNEW =>
'select * from illrequest where completed_date is null and status<>? order by placement_date asc',
    };
    if ( $rs_type =~ m/NEW/sm ) {    #NEW || OPENNOTNEW
        push @bind_values, $cfg->new_request_status();
    }
    if ( $stmt->{$rs_type} ) {
        my $requests =
          $dbh->selectall_arrayref( $stmt->{$rs_type}, { Slice => {} },
            @bind_values );

        #my @formatted_reqs = map { _opac_fmt_req($_); } @{$requests};
        #return \@formatted_reqs;
        my $result_set = [];
        @{$result_set} = map { C4::ILL::Request->new($_); } @{$requests};
        foreach my $r ( @{$result_set} ) {
            $r->retrieve_attributes();
        }

        return $result_set;
    }
    carp "GetAllILL called with invalid type:$rs_type";
    return;
}

1;
