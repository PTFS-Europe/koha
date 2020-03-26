package Koha::DBIx::Component::L10nSource;

use Modern::Perl;
use base 'DBIx::Class';

=head1 NAME

Koha::DBIx::Component::L10nSource

=head1 SYNOPSIS

    __PACKAGE__->load_components('+Koha::DBIx::Component::L10nSource')

    sub insert {
        my $self = shift;
        my $result = $self->next::method(@_);
        my @sources = $self->result_source->resultset->get_column('label')->all;
        $self->update_l10n_source('somecontext', @sources);
        return $result;
    }

    sub update {
        my $self = shift;
        my $is_column_changed = $self->is_column_changed('label');
        my $result = $self->next::method(@_);
        if ($is_column_changed) {
            my @sources = $self->result_source->resultset->get_column('label')->all;
            $self->update_l10n_source('somecontext', @sources);
        }
        return $result;
    }

    sub delete {
        my $self = shift;
        my $result = $self->next::method(@_);
        my @sources = $self->result_source->resultset->get_column('label')->all;
        $self->update_l10n_source('somecontext', @sources);
        return $result;
    }

=head1 METHODS

=head2 update_l10n_source

    $self->update_l10n_source($group, $key, $text)

Update or create an entry in l10n_source

=cut

sub update_l10n_source {
    my ($self, $group, $key, $text) = @_;

    my $l10n_source_rs = $self->result_source->schema->resultset('L10nSource');
    $l10n_source_rs->update_or_create(
        {
            group => $group,
            key   => $key,
            text  => $text,
        },
        {
            key => 'group_key',
        }
    );
}

=head2 delete_l10n_source

    $self->delete_l10n_source($group, $key, $text)

Remove an entry from l10n_source

=cut

sub delete_l10n_source {
    my ($self, $group, $key) = @_;

    my $l10n_source_rs = $self->result_source->schema->resultset('L10nSource');
    $l10n_source_rs->search(
        {
            group => $group,
            key   => $key,
        }
    )->delete();
}

1;
