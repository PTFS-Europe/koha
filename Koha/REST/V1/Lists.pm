package Koha::REST::V1::Lists;

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
use Koha::Virtualshelf;
use Koha::Virtualshelves;
use Koha::Virtualshelfcontent;

sub list {
    my $c = shift->openapi->valid_input or return;

    my @lists;
    my $virtualshelves = Koha::Virtualshelves->search();
    while (my $list = $virtualshelves->next) {
        push @lists, {
            id        => $list->id,
            shelfname => $list->shelfname,
            owner     => $list->owner,
            public    => $list->public,
        };
    }

    return $c->render(json => \@lists);
}

sub create {
    my $c = shift->openapi->valid_input or return;
    my $params = $c->req->json;

    my $list = Koha::Virtualshelf->new({
        shelfname => $params->{shelfname},
        owner     => $params->{owner},
        public    => $params->{public} // 0,
    })->store;

    # Add biblios to the newly created list
    if (exists $params->{biblionumbers} && ref $params->{biblionumbers} eq 'ARRAY') {
        foreach my $biblionumber (@{$params->{biblionumbers}}) {
            Koha::Virtualshelfcontent->new({
                shelfnumber  => $list->shelfnumber,
                biblionumber => $biblionumber,
                dateadded    => DateTime->now,
                borrowernumber => $params->{owner},
            })->store;
        }
    }

    return $c->render(status => 201, json => { id => $list->id });
}


sub read {
    my $c = shift->openapi->valid_input or return;
    my $id = $c->param('id');

    my $list = Koha::Virtualshelves->find($id);
    return $c->render(status => 404, json => { error => 'Not found' }) unless $list;

    my $records_rs = $list->get_contents;
    my @records;
    while (my $record = $records_rs->next) {
        push @records, {
            shelfnumber   => $record->shelfnumber,
            biblionumber  => $record->biblionumber,
            dateadded     => $record->dateadded,
            borrowernumber => $record->borrowernumber,
        };
    }

    return $c->render(json => {
        id       => $list->id,
        shelfname => $list->shelfname,
        owner    => $list->owner,
        public   => $list->public,
        records  => \@records,
    });
}

sub update {
    my $c = shift->openapi->valid_input or return;
    my $id = $c->param('id');
    my $params = $c->req->json;

    my $list = Koha::Virtualshelves->find($id);
    return $c->render(status => 404, json => { error => 'Not found' }) unless $list;

    $list->shelfname($params->{shelfname}) if $params->{shelfname};
    $list->public($params->{public}) if defined $params->{public};
    $list->store;

    # Add biblios to the list
    if (exists $params->{add_biblionumbers} && ref $params->{add_biblionumbers} eq 'ARRAY') {
        foreach my $biblionumber (@{$params->{add_biblionumbers}}) {
            $list->add_biblio($biblionumber, $list->owner);
        }
    }

    # Remove biblios from the list
    if (exists $params->{remove_biblionumbers} && ref $params->{remove_biblionumbers} eq 'ARRAY') {
        $list->remove_biblios({
            biblionumbers  => $params->{remove_biblionumbers},
            borrowernumber => $list->owner,
        });
    }

    return $c->render(json => { success => 1 });
}

sub delete {
    my $c = shift->openapi->valid_input or return;
    my $id = $c->param('id');

    my $list = Koha::Virtualshelves->find($id);
    return $c->render(status => 404, json => { error => 'Not found' }) unless $list;

    $list->delete;

    return $c->render(json => { success => 1 });
}
1;
