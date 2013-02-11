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

sub match_captures { 
  my ( $self, $c, $captures ) = @_;
  ## It would seem that now that we can match captures, we could remove a lot
  ## of the capture_args to args mapping all around.  I gave it a go, but was
  ## not trival, contact jnap on irc for what I tried if you want to try.
  ##  return $self->_match_has_expected_capture_args($captures) &&
    return $self->_match_has_expected_http_method($c->req->method);
}

sub match {
  my ( $self, $c ) = @_;
  return $self->_match_has_expected_args($c->req->args) &&
    $self->_match_has_expected_http_method($c->req->method);
}

sub _match_has_expected_args {
  my ($self, $req_args) = @_;
  return 1 unless exists $self->attributes->{Args};
  my $args = $self->attributes->{Args}[0];
  return 1 unless defined($args) && length($args);
  return scalar( @{$req_args} ) == $args;
}

sub _match_has_expected_capture_args {
  my ($self, $req_args) = @_;
  return 1 unless exists $self->attributes->{CaptureArgs};
  my $args = $self->attributes->{CaptureArgs}[0];
  return 1 unless defined($args) && length($args);
  return scalar( @{$req_args} ) == $args;
}

sub _match_has_expected_http_method {
  my ($self, $method) = @_;
  my @methods = @{ $self->attributes->{Method} || [] };
  if(scalar @methods) {
    my $result = scalar(grep { lc($_) eq lc($method) } @methods) ? 1:0;
    return $result;
  } else {
    ## No HTTP Methods to check
    return 1;
  }
}

sub compare {
    my ($a1, $a2) = @_;

    my ($a1_args) = @{ $a1->attributes->{Args} || [] };
    my ($a2_args) = @{ $a2->attributes->{Args} || [] };

    $_ = looks_like_number($_) ? $_ : ~0
        for $a1_args, $a2_args;

    return $a1_args <=> $a2_args;
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

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS

=head2 attributes

The sub attributes that are set for this action, like Local, Path, Private
and so on. This determines how the action is dispatched to.

=head2 class

Returns the name of the component where this action is defined.
Derived by calling the L<Catalyst::Component/catalyst_component_name|catalyst_component_name>
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

Compares 2 actions based on the value of the C<Args> attribute, with no C<Args>
having the highest precedence.

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

=head2 meta

Provided by Moose.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
