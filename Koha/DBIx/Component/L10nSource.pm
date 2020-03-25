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

    $self->update_l10n_source($context, @sources)

Ensure that all sources in C<@sources>and only them are present in l10n_source
for a given C<$context>

=cut

sub update_l10n_source {
    my ($self, $context, @sources) = @_;

    my $l10n_source_rs = $self->result_source->schema->resultset('L10nSource')->search({ context => $context });

    # Insert missing l10n_source rows
    foreach my $source (@sources) {
        my $count = $l10n_source_rs->search({ source => $source })->count;
        if ($count == 0) {
            $l10n_source_rs->create({ source => $source });
        }
    }

    # Remove l10n_source rows that do not match an existing source
    my %sources = map { $_ => undef } @sources;
    my @l10n_sources = grep { !exists $sources{$_->source} } $l10n_source_rs->all;
    foreach my $l10n_source (@l10n_sources) {
        $l10n_source->delete;
    }
}

1;
