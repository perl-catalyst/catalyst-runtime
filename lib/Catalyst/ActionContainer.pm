package Catalyst::ActionContainer;

use strict;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/part actions/);

use overload (

    # Stringify to path part for tree search
    q{""} => sub { shift->{part} },

);

sub new {
    my ( $class, $fields ) = @_;

    $fields = { part => $fields, actions => {} } unless ref $fields;

    $class->SUPER::new($fields);
}

=head1 NAME

Catalyst::ActionContainer - Catalyst Action Container

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a container for actions. The dispatcher sets up a tree of these
to represent the various dispatch points in your application.

=head1 METHODS

=head2 get_action($name)

Returns an action from this container based on the action name, or undef

=cut

sub get_action {
    my ( $self, $name ) = @_;
    return $self->actions->{$name} if defined $self->actions->{$name};
    return;
}

=head2 add_action($action, [ $name ])

Adds an action, optionally providing a name to override $action->name

=cut

sub add_action {
    my ( $self, $action, $name ) = @_;
    $name ||= $action->name;
    $self->actions->{$name} = $action;
}

=head2 actions

Accessor to the actions hashref, containing all actions in this container.

=head2 part

Accessor to the path part this container resolves to. Also what the container
stringifies to.

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
