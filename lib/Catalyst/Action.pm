package Catalyst::Action;

use strict;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/class namespace reverse attributes name code/);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to encapsulated action coderef
    '&{}' => sub { shift->{code} },

    # Make general $stuff still work
    fallback => 1,

);

=head1 NAME

Catalyst::Action - Catalyst Action

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This class represents a Catalyst Action. You can access the object for the 
currently dispatched action via $c->action

=head1 METHODS

=head2 attributes

The sub attributes that are set for this action, like Local, Path, Private
and so on.

=head2 class

Returns the class name of this action

=head2 code

Returns a code reference to this action

=head2 execute( $c )

Execute this action against a context

=cut

sub execute {    # Execute ourselves against a context
    my ( $self, $c ) = @_;
    local $c->namespace = $self->namespace;
    return $c->execute( $self->class, $self );
}

=head2 match( $c )

Check Args attribute, and makes sure number of args matches the setting.

=cut

sub match {
    my ( $self, $c ) = @_;
    return 1 unless exists $self->attributes->{Args};
    return scalar(@{$c->req->args}) == $self->attributes->{Args}[0];
}

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

1;
