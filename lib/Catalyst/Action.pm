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
use Moose::Util::TypeConstraints ();
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

has args_constraints => (
  is=>'ro',
  traits=>['Array'],
  isa=>'ArrayRef',
  required=>1,
  lazy=>1,
  builder=>'_build_args_constraints',
  handles => {
    has_args_constraints => 'count',
    number_of_args => 'count',
    all_args_constraints => 'elements',
  });

  sub _build_args_constraints {
    my $self = shift;
    my @arg_protos = @{$self->attributes->{Args}||[]};

    return [] unless scalar(@arg_protos);
    # If there is only one arg and it looks like a number
    # we assume its 'classic' and the number is the number of
    # constraints.
    my @args = ();
    if(
      scalar(@arg_protos) == 1 &&
      looks_like_number($arg_protos[0])
    ) {
      return [];
    } else {
      @args = map { Moose::Util::TypeConstraints::find_or_parse_type_constraint($_) || die "$_ is not a constraint!" } @arg_protos;
    }

    return \@args;
  }

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
    warn "number args = ${\$self->number_of_args} for ${\$self->name}";
    return 1 unless $self->number_of_args;
    #my $args = $self->attributes->{Args}[0];
    #return 1 unless defined($args) && length($args); The "Args" slurpy case, remove for now.
    if( scalar( @{ $c->req->args } ) == $self->number_of_args ) {
      return 1 unless $self->has_args_constraints;
      for my $i($#{ $c->req->args }) {
        $self->args_constraints->[$i]->check($c->req->args->[$i]) || return 0;
      }
      return 1;
    } else {
      return 0;
    }
}

sub match_captures { 1 }

sub compare {
    my ($a1, $a2) = @_;
    my ($a1_args) = $a1->number_of_args;
    my ($a2_args) = $a2->number_of_args;

    return $a1_args <=> $a2_args;
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
