package Koha::Service::Transcode;

use Modern::Perl;
use JSON;

use base 'Koha::Service';

use Koha::Database;
use Data::Dumper;

sub new {
    my ($class) = @_;

    return $class->SUPER::new(
        {
            needed_flags => { admin => 'edit_transcodes' },
            routes       => [
                [ qr'GET /(\d*)',    'read' ],
                [ qr'POST /',        'create' ],
                [ qr'PUT /(.+)',    'update' ],
                [ qr'DELETE /(\d+)', 'delete' ],
            ]
        }
    );
}

sub create {
    my ($self) = @_;

    my $response = {};
    my $input    = from_json( $self->query->param('POSTDATA') );
    warn "input: " . Dumper($input);

    my $schema    = Koha::Database->new()->schema();
    my $transcode = $schema->resultset('CashTranscode')->create($input);

    unless ($transcode) {
        $self->output( $response, { status => '200 OK', type => 'json' } );
        return;
    }

    $response = { $transcode->get_columns };
    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub read {
    my ( $self, $code ) = @_;

    my $response = {};
    my $schema   = Koha::Database->new()->schema();
    my $filter   = {};
    if ($code) {
        $filter->{'code'} = $code;
    }
    my $transcodes_rs = $schema->resultset('CashTranscode')->search( $filter, );

    $response->{recordsTotal}    = $transcodes_rs->count;
    $response->{recordsFiltered} = $transcodes_rs->count;
    while ( my $transcode = $transcodes_rs->next ) {
        push @{ $response->{data} }, { $transcode->get_columns };
    }

    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub update {
    my ( $self, $code ) = @_;

    my $response = {};
    my $input    = from_json( $self->query->param('PUTDATA') );
    my $schema   = Koha::Database->new()->schema();
    my $transcode =
      $schema->resultset('CashTranscode')->find( { code => $code } );

    unless ($transcode) {
        $self->output( {}, { status => '404', type => 'json' } );
        return;
    }

    $transcode->update($input)->discard_changes();
    $self->output( { $transcode->get_columns },
        { status => '200 OK', type => 'json' } );

    return;
}

sub delete {
    my ( $self, $code ) = @_;

}

1;
