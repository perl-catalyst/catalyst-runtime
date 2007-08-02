package Catalyst::Action;

use strict;
use base qw/Class::Accessor::Fast/;


=head1 NAME

Catalyst::Action - Catalyst Action

=head1 SYNOPSIS

    <form action="[%c.uri_for(c.action.reverse)%]">

=head1 DESCRIPTION

This class represents a Catalyst Action. You can access the object for the 
currently dispatched action via $c->action. See the L<Catalyst::Dispatcher>
for more information on how actions are dispatched. Actions are defined in
L<Catalyst::Controller> subclasses.

=cut

__PACKAGE__->mk_accessors(qw/class namespace reverse attributes name code/);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to execute to invoke the encapsulated action coderef
    '&{}' => sub { my $self = shift; sub { $self->execute(@_); }; },

    # Make general $stuff still work
    fallback => 1,

);

sub dispatch {    # Execute ourselves against a context
    my ( $self, $c ) = @_;
    local $c->namespace = $self->namespace;
    return $c->execute( $self->class, $self );
}

sub execute {
  my $self = shift;
  $self->{code}->(@_);
}

sub match {
    my ( $self, $c ) = @_;
    return 1 unless exists $self->attributes->{Args};
    my $args = $self->attributes->{Args}[0];
    return 1 unless defined($args) && length($args);
    return scalar( @{ $c->req->args } ) == $args;
}

1;

__END__

=head1 METHODS

=head2 attributes

The sub attributes that are set for this action, like Local, Path, Private
and so on. This determines how the action is dispatched to.

=head2 class

Returns the class name where this action is defined.

=head2 code

Returns a code reference to this action.

=head2 dispatch( $c )

Dispatch this action against a context

=head2 execute( $controller, $c, @args )

Execute this action's coderef against a given controller with a given
context and arguments

=head2 match( $c )

Check Args attribute, and makes sure number of args matches the setting.
Always returns true if Args is omitted.

=head2 namespace

Returns the private namespace this action lives in.

=head2 reverse

Returns the private path for this action.

=head2 name

returns the sub name of this action.

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
