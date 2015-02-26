package Catalyst::Action;

=head1 NAME

Catalyst::Action - Catalyst Action

=head1 SYNOPSIS

    <form action="[%c.uri_for(c.action)%]">

    $c->forward( $action->private_path );

=head1 DESCRIPTION

This class represents a Catalyst Action. You can access the object for the
currently dispatched action via $c->action. See the L<Catalyst::Dispatcher>
for more information on how actions are dispatched. Actions are defined in
L<Catalyst::Controller> subclasses.

=cut

use Moose;
use Scalar::Util 'looks_like_number';
with 'MooseX::Emulate::Class::Accessor::Fast';
use namespace::clean -except => 'meta';

has class => (is => 'rw');
has namespace => (is => 'rw');
has 'reverse' => (is => 'rw');
has attributes => (is => 'rw');
has name => (is => 'rw');
has code => (is => 'rw');
has private_path => (
  reader => 'private_path',
  isa => 'Str',
  lazy => 1,
  required => 1,
  default => sub { '/'.shift->reverse },
);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to execute to invoke the encapsulated action coderef
    '&{}' => sub { my $self = shift; sub { $self->execute(@_); }; },

    # Make general $stuff still work
    fallback => 1,

);



no warnings 'recursion';

sub dispatch {    # Execute ourselves against a context
    my ( $self, $c ) = @_;
    return $c->execute( $self->class, $self );
}

sub execute {
  my $self = shift;
  $self->code->(@_);
}

sub match {
    my ( $self, $c ) = @_;
    #would it be unreasonable to store the number of arguments
    #the action has as its own attribute?
    #it would basically eliminate the code below.  ehhh. small fish
    return 1 unless exists $self->attributes->{Args};
    my $args = $self->attributes->{Args}[0];
    return 1 unless defined($args) && length($args);
    return scalar( @{ $c->req->args } ) == $args;
}

sub match_captures { 1 }

sub compare {
    my ($a1, $a2) = @_;

    my %cmp = (
        a1 => {},
        a2 => {},
    );

    ( $cmp{a1}{Args} ) = @{ $a1->attributes->{Args} || [] };
    ( $cmp{a2}{Args} ) = @{ $a2->attributes->{Args} || [] };

     $cmp{$_}{Args}
        = looks_like_number( $cmp{$_}{Args} ) ? $cmp{$_}{Args} : ~0
            for ('a1', 'a2');

    for my $attr ('Method', 'Scheme', 'Consumes') {
        $cmp{a1}{$attr} = @{ $a1->attributes->{$attr} || [] };
        $cmp{a2}{$attr} = @{ $a2->attributes->{$attr} || [] };
    }

    return (
           $cmp{a1}{Args}     <=> $cmp{a2}{Args}
        || $cmp{a2}{Method}   <=> $cmp{a1}{Method}
        || $cmp{a2}{Scheme}   <=> $cmp{a1}{Scheme}
        || $cmp{a2}{Consumes} <=> $cmp{a1}{Consumes}
    );
}

sub number_of_args {
    my ( $self ) = @_;
    return 0 unless exists $self->attributes->{Args};
    return $self->attributes->{Args}[0];
}

sub number_of_captures {
    my ( $self ) = @_;

    return 0 unless exists $self->attributes->{CaptureArgs};
    return $self->attributes->{CaptureArgs}[0] || 0;
}

sub scheme {
  return exists $_[0]->attributes->{Scheme} ? $_[0]->attributes->{Scheme}[0] : undef;
}

sub list_extra_info {
  my $self = shift;
  return {
    Args => $self->attributes->{Args}[0],
    CaptureArgs => $self->number_of_captures,
  }
} 

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS

=head2 attributes

The sub attributes that are set for this action, like Local, Path, Private
and so on. This determines how the action is dispatched to.

=head2 class

Returns the name of the component where this action is defined.
Derived by calling the L<catalyst_component_name|Catalyst::Component/catalyst_component_name>
method on each component.

=head2 code

Returns a code reference to this action.

=head2 dispatch( $c )

Dispatch this action against a context.

=head2 execute( $controller, $c, @args )

Execute this action's coderef against a given controller with a given
context and arguments

=head2 match( $c )

Check Args attribute, and makes sure number of args matches the setting.
Always returns true if Args is omitted.

=head2 match_captures ($c, $captures)

Can be implemented by action class and action role authors. If the method
exists, then it will be called with the request context and an array reference
of the captures for this action.

Returning true from this method causes the chain match to continue, returning
makes the chain not match (and alternate, less preferred chains will be attempted).


=head2 compare

Compares 2 actions based on the value of the C<Args>, C<Method>, C<Scheme> and C<Consumes> attributes.
With no C<Args>, max C<Method>, C<Scheme> and C<Consumes> having the highest precedence.

=head2 namespace

Returns the private namespace this action lives in.

=head2 reverse

Returns the private path for this action.

=head2 private_path

Returns absolute private path for this action. Unlike C<reverse>, the
C<private_path> of an action is always suitable for passing to C<forward>.

=head2 name

Returns the sub name of this action.

=head2 number_of_args

Returns the number of args this action expects. This is 0 if the action doesn't take any arguments and undef if it will take any number of arguments.

=head2 number_of_captures

Returns the number of captures this action expects for L<Chained|Catalyst::DispatchType::Chained> actions.

=head2 list_extra_info

A HashRef of key-values that an action can provide to a debugging screen

=head2 scheme

Any defined scheme for the action

=head2 meta

Provided by Moose.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
