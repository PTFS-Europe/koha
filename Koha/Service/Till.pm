package Koha::Service::Till;

use Modern::Perl;
use CGI::Cookie;
use JSON;
use Carp;

use base 'Koha::Service';

use Koha::Database;

sub new {
    my ($class) = @_;

    return $class->SUPER::new(
        {
            routes => [
                [ qr{GET /(\d*)},    'tread' ],
                [ qr{POST /},        'create' ],
                [ qr{PUT /(\d+)},    'update' ],
                [ qr{DELETE /(\d+)}, 'tdelete' ],
            ]
        }
    );
}

sub create {
    my ($self) = @_;

    my $response = {};
    my $input    = from_json( $self->query->param('POSTDATA') );

    my $schema = Koha::Database->new()->schema();
    my $till   = $schema->resultset('CashTill')->create($input);

    if ( !defined $till ) {
        $self->output( $response, { status => '200 OK', type => 'json' } );
        return;
    }

    $response = { $till->get_columns };
    $response->{branchname} = $till->branch->get_column('branchname');
    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub tread {
    my ( $self, $tillid ) = @_;

    my $response = {};
    my $schema   = Koha::Database->new()->schema();
    my $filter   = {};
    if ($tillid) {
        $filter->{tillid} = $tillid;
        my $till_cookie = CGI::Cookie->new(
            -name     => 'KohaStaffClient',
            -value    => $tillid,
            -HttpOnly => 1,
            -expires  => '+3y'
        );
        $self->cookie( [ $self->cookie, $till_cookie ] );
    }
    my $tills_rs = $schema->resultset('CashTill')->search(
        $filter,
        {
            prefetch  => 'branch',
            '+select' => ['branch.branchname'],
            '+as'     => ['branchname']
        }
    );

    $response->{recordsTotal} = $response->{recordsFiltered} = $tills_rs->count;
    while ( my $till = $tills_rs->next ) {
        push @{ $response->{data} }, { $till->get_columns };
    }

    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub other {
    my ( $self, $tillid ) = @_;
    carp "Other tillid: $tillid";
    return;
}

sub update {
    my ( $self, $tillid ) = @_;

    my $response = {};
    my $input    = from_json( $self->query->param('PUTDATA') );
    my $schema   = Koha::Database->new()->schema();
    my $till = $schema->resultset('CashTill')->find( { tillid => $tillid } );

    if ( !defined $till ) {
        $self->output( {}, { status => '404', type => 'json' } );
        return;
    }

    $till->update($input)->discard_changes();
    $self->output( { $till->get_columns },
        { status => '200 OK', type => 'json' } );

    return;
}

sub tdelete {
    my ( $self, $tillid ) = @_;

    # prob set  a deleted flag

    return;
}

1;
