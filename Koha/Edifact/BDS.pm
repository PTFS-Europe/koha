package Koha::Edifact::BDS;
use strict;
use warnings;
use C4::Context;

# Edifact skeleton fields
#   biblionumber integer primary key,
#   ordernumber integer not null,
#   ean varchar(12),
#   status varchar(10),
#   lastactivity timestamp
# status 'created' 'upgraded', 'changedext'
sub new {
    my $class = shift;

    my $self = {};
    $self->{dbh} = C4::Context->dbh;
    $self->{insert} =
      $self->{dbh}->prepare(
q{insert into edifact_skeleton (biblionumber, ordernumber, ean, status) values (?,?,?,'created')}
      );
    bless $self, $class;

    return $self;
}

sub add_entry {
    my ( $self, $args ) = @_;
    $self->{insert}->execute( $args->{biblionumber}, $args->{ordernumber}, $args->{ean} );
    return;
}

1;

