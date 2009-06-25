package Catalyst::ActionContainer;

=head1 NAME

Catalyst::ActionContainer - Catalyst Action Container

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a container for actions. The dispatcher sets up a tree of these
to represent the various dispatch points in your application.

=cut

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';

has part => (is => 'rw', required => 1);
has actions => (is => 'rw', required => 1, lazy => 1, default => sub { {} });

around BUILDARGS => sub {
    my ($next, $self, @args) = @_;
    unshift @args, 'part' if scalar @args == 1 && !ref $args[0];
    return $self->$next(@args);
};

no Moose;

use overload (
    # Stringify to path part for tree search
    q{""} => sub { shift->part },
);

sub get_action {
    my ( $self, $name ) = @_;
    return $self->actions->{$name} if defined $self->actions->{$name};
    return;
}

sub add_action {
    my ( $self, $action, $name ) = @_;
    $name ||= $action->name;
    $self->actions->{$name} = $action;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS

=head2 new(\%data | $part)

Can be called with { part => $part, actions => \%actions } for full
construction or with just a part, which will result in an empty actions
hashref to be populated via add_action later

=head2 get_action($name)

Returns an action from this container based on the action name, or undef

=head2 add_action($action, [ $name ])

Adds an action, optionally providing a name to override $action->name

=head2 actions

Accessor to the actions hashref, containing all actions in this container.

=head2 part

Accessor to the path part this container resolves to. Also what the container
stringifies to.

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
