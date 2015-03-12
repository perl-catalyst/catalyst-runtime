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

has number_of_args => (
  is=>'ro',
  init_arg=>undef,
  isa=>'Int|Undef',
  required=>1,
  lazy=>1,
  builder=>'_build_number_of_args');

  sub _build_number_of_args {
    my $self = shift;
    if( ! exists $self->attributes->{Args} ) {
      # When 'Args' does not exist, that means we want 'any number of args'.
      return undef;
    } elsif(!defined($self->attributes->{Args}[0])) {
      # When its 'Args' that internal cue for 'unlimited'
      return undef;
    } elsif(
      scalar(@{$self->attributes->{Args}}) == 1 &&
      looks_like_number($self->attributes->{Args}[0])
    ) {
      # 'Old school' numberd args (is allowed to be undef as well)
      return $self->attributes->{Args}[0];
    } else {
      # New hotness named arg constraints
      return $self->number_of_args_constraints;
    }
  }

sub normalized_arg_number {
  return defined($_[0]->number_of_args) ? $_[0]->number_of_args : ~0;
}

has args_constraints => (
  is=>'ro',
  init_arg=>undef,
  traits=>['Array'],
  isa=>'ArrayRef',
  required=>1,
  lazy=>1,
  builder=>'_build_args_constraints',
  handles => {
    has_args_constraints => 'count',
    number_of_args_constraints => 'count',
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
      return \@args;
    } else {
      @args =
        map { Moose::Util::TypeConstraints::find_or_parse_type_constraint($_) || die "$_ is not a constraint!" } 
        @arg_protos;
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

    # If infinite args, we always match
    return 1 if $self->normalized_arg_number == ~0;

    # There there are arg constraints, we must see to it that the constraints
    # check positive for each arg in the list.
    if($self->has_args_constraints) {
      # If there is only one type constraint, and its a Ref or subtype of Ref,
      # That means we expect a reference, so use the full args arrayref.
      if(
        $self->number_of_args_constraints == 1 &&
        $self->args_constraints->[0]->is_a_type_of('Ref')
      ) {
        return $self->args_constraints->[0]->check($c->req->args);
      } else {
        for my $i($#{ $c->req->args }) {
          $self->args_constraints->[$i]->check($c->req->args->[$i]) || return 0;
        }
        return 1;
      }
    } else {
      # Otherwise, we just need to match the number of args.
      return scalar( @{ $c->req->args } ) == $self->normalized_arg_number;
    }
}

sub match_captures { 1 }

sub compare {
    my ($a1, $a2) = @_;
    return $a1->normalized_arg_number <=> $a2->normalized_arg_number;
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

Returns the number of args this action expects. This is 0 if the action doesn't
take any arguments and undef if it will take any number of arguments.

=head2 normalized_arg_number

For the purposes of comparison we normalize 'number_of_args' so that if it is
undef we mean ~0 (as many args are we can think of).

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


