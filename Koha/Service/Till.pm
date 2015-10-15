package Koha::Service::Till;

use Modern::Perl;
use CGI::Cookie;
use JSON;

use base 'Koha::Service';

use Koha::Database;

sub new {
    my ($class) = @_;

    return $class->SUPER::new(
        {
            routes => [
                [ qr{GET /(\d*)},    'tread' ],
                [ qr{POST /},        'create' ],
                [ qr{PUT /},         'update' ],
                [ qr{DELETE /(\d+)}, 'archive' ],
            ]
        }
    );
}

sub create {
    my ($self) = @_;

    my $input = from_json( $self->query->param('POSTDATA') );

    my $schema = Koha::Database->new()->schema();
    my $till   = $schema->resultset('CashTill')->create($input);

    if ( !defined $till ) {
        $self->output( {}, { status => '200 OK', type => 'json' } );
        return;
    }

    my $response = {};
    $response = { $till->get_columns };
    $response->{branchname} = $till->branch->get_column('branchname');
    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub tread {
    my ( $self, $tillid ) = @_;

    my $schema = Koha::Database->new()->schema();
    my $filter = {};
    if ($tillid) {
        $filter->{tillid} = $tillid;
        my $till_cookie = CGI::Cookie->new(
            -name     => 'KohaStaffClientTill',
            -value    => $tillid,
            -HttpOnly => 1,
            -expires  => '+3y'
        );
        $self->cookie( [ $self->cookie, $till_cookie ] );
    }
    my @tills = $schema->resultset('CashTill')->search(
        $filter,
        {
            prefetch  => 'branch',
            '+select' => ['branch.branchname'],
            '+as'     => ['branchname']
        }
    );

    my $response = {
        recordsTotal => scalar @tills,
        data         => \@tills,
    };

    #    while ( my $till = $tills_rs->next ) {
    #        push @{ $response->{data} }, { $till->get_columns };
    #    }

    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub other {
    my ( $self, $tillid ) = @_;
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

    my $response = {};
    my $schema   = Koha::Database->new()->schema();
    my $till =
      $schema->resultset('CashTill')->find( { tillid => $tillid } );

    if ( !$till ) {
        $self->output( {}, { status => '404', type => 'json' } );
        return;
    }

    my $archive = { archived => '1' };
    $till->update($archive)->discard_changes();
    $self->output( { $till->get_columns },
        { status => '200 OK', type => 'json' } );

    return;
}

1;
