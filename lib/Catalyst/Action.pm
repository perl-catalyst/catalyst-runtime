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
use Scalar::Util 'looks_like_number', 'blessed';
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
      # 'Old school' numbered args (is allowed to be undef as well)
      return $self->attributes->{Args}[0];
    } else {
      # New hotness named arg constraints
      return $self->number_of_args_constraints;
    }
  }

sub normalized_arg_number {
  return defined($_[0]->number_of_args) ? $_[0]->number_of_args : ~0;
}

has number_of_args_constraints => (
  is=>'ro',
  isa=>'Int|Undef',
  init_arg=>undef,
  required=>1,
  lazy=>1,
  builder=>'_build_number_of_args_constraints');

  sub _build_number_of_args_constraints {
    my $self = shift;
    return unless $self->has_args_constraints;

    # If there is one constraint and its a ref, we need to decide
    # if this number 'unknown' number or if the ref allows us to
    # determine a length.

    if(scalar @{$self->args_constraints} == 1) {
      my $tc = $self->args_constraints->[0];
      if(
        $tc->can('is_strictly_a_type_of') &&
        $tc->is_strictly_a_type_of('Tuple'))
      {
        my @parameters = @{ $tc->parameters||[]};
        if( defined($parameters[-1]) and exists($parameters[-1]->{slurpy})) {
          return undef;
        } else {
          return my $total_params = scalar(@parameters);
        }
      } elsif($tc->is_a_type_of('Ref')) {
        return undef;
      } else {
        return 1; # Its a normal 1 arg type constraint.
      }
    } else {
      # We need to loop through and error on ref types.  We don't allow a ref type
      # in the middle.
      my $total = 0;
      foreach my $tc( @{$self->args_constraints}) {
        if($tc->is_a_type_of('Ref')) {
          die "$tc is a Ref type constraint.  You cannot mix Ref and non Ref type constraints in Args for action ${\$self->reverse}";
        } else {
          ++$total;
        }
      }
      return $total;
    }
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
    args_constraint_count => 'count',
  });

  sub _build_args_constraints {
    my $self = shift;
    my @arg_protos = @{$self->attributes->{Args}||[]};

    return [] unless scalar(@arg_protos);
    return [] unless defined($arg_protos[0]);

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
        map {  my @tc = $self->resolve_type_constraint($_); scalar(@tc) ? @tc : die "$_ is not a constraint!" }
        @arg_protos;
    }
    return \@args;
  }

has number_of_captures_constraints => (
  is=>'ro',
  isa=>'Int|Undef',
  init_arg=>undef,
  required=>1,
  lazy=>1,
  builder=>'_build_number_of_capture_constraints');

  sub _build_number_of_capture_constraints {
    my $self = shift;
    return unless $self->has_captures_constraints;

    # If there is one constraint and its a ref, we need to decide
    # if this number 'unknown' number or if the ref allows us to
    # determine a length.

    if(scalar @{$self->captures_constraints} == 1) {
      my $tc = $self->captures_constraints->[0];
      if(
        $tc->can('is_strictly_a_type_of') &&
        $tc->is_strictly_a_type_of('Tuple'))
      {
        my @parameters = @{ $tc->parameters||[]};
        if( defined($parameters[-1]) and exists($parameters[-1]->{slurpy})) {
          return undef;
        } else {
          return my $total_params = scalar(@parameters);
        }
      } elsif($tc->is_a_type_of('Ref')) {
        die "You cannot use CaptureArgs($tc) in ${\$self->reverse} because we cannot determined the number of its parameters";
      } else {
        return 1; # Its a normal 1 arg type constraint.
      }
    } else {
      # We need to loop through and error on ref types.  We don't allow a ref type
      # in the middle.
      my $total = 0;
      foreach my $tc( @{$self->captures_constraints}) {
        if($tc->is_a_type_of('Ref')) {
          die "$tc is a Ref type constraint.  You cannot mix Ref and non Ref type constraints in CaptureArgs for action ${\$self->reverse}";
        } else {
          ++$total;
        }
      }
      return $total;
    }
  }

has captures_constraints => (
  is=>'ro',
  init_arg=>undef,
  traits=>['Array'],
  isa=>'ArrayRef',
  required=>1,
  lazy=>1,
  builder=>'_build_captures_constraints',
  handles => {
    has_captures_constraints => 'count',
    captures_constraints_count => 'count',
  });

  sub _build_captures_constraints {
    my $self = shift;
    my @arg_protos = @{$self->attributes->{CaptureArgs}||[]};

    return [] unless scalar(@arg_protos);
    return [] unless defined($arg_protos[0]);
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
        map {  my @tc = $self->resolve_type_constraint($_); scalar(@tc) ? @tc : die "$_ is not a constraint!" }
        @arg_protos;
    }

    return \@args;
  }

sub resolve_type_constraint {
  my ($self, $name) = @_;

  if(defined($name) && blessed($name) && $name->can('check')) {
    # Its already a TC, good to go.
    return $name;
  }

  # This is broken for when there is more than one constraint
  if($name=~m/::/) {
    eval "use Type::Registry; 1" || die "Can't resolve type constraint $name without installing Type::Tiny";
    my $tc =  Type::Registry->new->foreign_lookup($name);
    return defined $tc ? $tc : die "'$name' not a full namespace type constraint in ${\$self->private_path}";
  }
  
  my @tc = grep { defined $_ } (eval("package ${\$self->class}; $name"));

  unless(scalar @tc) {
    # ok... so its not defined in the package.  we need to look at all the roles
    # and superclasses, look for attributes and figure it out.
    # Superclasses take precedence;

    my @supers = $self->class->can('meta') ? map { $_->meta } $self->class->meta->superclasses : ();
    my @roles = $self->class->can('meta') ? $self->class->meta->calculate_all_roles : ();

    # So look through all the super and roles in order and return the
    # first type constraint found. We should probably find all matching
    # type constraints and try to do some sort of resolution.

    foreach my $parent (@roles, @supers) {
      if(my $m = $parent->get_method($self->name)) {
        if($m->can('attributes')) {
          my ($key, $value) = map { $_ =~ /^(.*?)(?:\(\s*(.+?)\s*\))?$/ }
            grep { $_=~/^Args\(/ or $_=~/^CaptureArgs\(/ }
              @{$m->attributes};
          next unless $value eq $name;
          my @tc = eval "package ${\$parent->name}; $name";
          if(scalar(@tc)) {
            return map { ref($_) ? $_ : Moose::Util::TypeConstraints::find_or_parse_type_constraint($_) } @tc;
          } else {
            return;
          }
        } 
      }
    }
    
    my $classes = join(',', $self->class, @roles, @supers);
    die "'$name' not a type constraint in '${\$self->private_path}', Looked in: $classes";
  }

  if(scalar(@tc)) {
    return map { ref($_) ? $_ : Moose::Util::TypeConstraints::find_or_parse_type_constraint($_) } @tc;
  } else {
    return;
  }
}

has number_of_captures => (
  is=>'ro',
  init_arg=>undef,
  isa=>'Int',
  required=>1,
  lazy=>1,
  builder=>'_build_number_of_captures');

  sub _build_number_of_captures {
    my $self = shift;
    if( ! exists $self->attributes->{CaptureArgs} ) {
      # If there are no defined capture args, thats considered 0.
      return 0;
    } elsif(!defined($self->attributes->{CaptureArgs}[0])) {
      # If you fail to give a defined value, that's also 0
      return 0;
    } elsif(
      scalar(@{$self->attributes->{CaptureArgs}}) == 1 &&
      looks_like_number($self->attributes->{CaptureArgs}[0])
    ) {
      # 'Old school' numbered captures
      return $self->attributes->{CaptureArgs}[0];
    } else {
      # New hotness named arg constraints
      return $self->number_of_captures_constraints;
    }
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
    return $self->match_args($c, $c->req->args);
}

sub match_args {
    my ($self, $c, $args) = @_;
    my @args = @{$args||[]};

    # There there are arg constraints, we must see to it that the constraints
    # check positive for each arg in the list.
    if($self->has_args_constraints) {
      # If there is only one type constraint, and its a Ref or subtype of Ref,
      # That means we expect a reference, so use the full args arrayref.
      if(
        $self->args_constraint_count == 1 &&
        (
          $self->args_constraints->[0]->is_a_type_of('Ref') ||
          $self->args_constraints->[0]->is_a_type_of('ClassName')
        )
      ) {
        # Ok, the the type constraint is a ref type, which is allowed to have
        # any number of args.  We need to check the arg length, if one is defined.
        # If we had a ref type constraint that allowed us to determine the allowed
        # number of args, we need to match that number.  Otherwise if there was an
        # undetermined number (~0) then we allow all the args.  This is more of an
        # Optimization since Tuple[Int, Int] would fail on 3,4,5 anyway, but this
        # way we can avoid calling the constraint when the arg length is incorrect.
        if(
          $self->normalized_arg_number == ~0 ||
          scalar( @args ) == $self->normalized_arg_number
        ) {
          return $self->args_constraints->[0]->check($args);
        } else {
          return 0;
        }
        # Removing coercion stuff for the first go
        #if($self->args_constraints->[0]->coercion && $self->attributes->{Coerce}) {
        #  my $coerced = $self->args_constraints->[0]->coerce($c) || return 0;
        #  $c->req->args([$coerced]);
        #  return 1;
        #}
      } else {
        # Because of the way chaining works, we can expect args that are totally not
        # what you'd expect length wise.  When they don't match length, thats a fail
        return 0 unless scalar( @args ) == $self->normalized_arg_number;

        for my $i(0..$#args) {
          $self->args_constraints->[$i]->check($args[$i]) || return 0;
        }
        return 1;
      }
    } else {
      # If infinite args with no constraints, we always match
      return 1 if $self->normalized_arg_number == ~0;

      # Otherwise, we just need to match the number of args.
      return scalar( @args ) == $self->normalized_arg_number;
    }
}

sub match_captures {
  my ($self, $c, $captures) = @_;
  my @captures = @{$captures||[]};

  return 1 unless scalar(@captures); # If none, just say its ok
  return $self->has_captures_constraints ?
    $self->match_captures_constraints($c, $captures) : 1;

  return 1;
}

sub match_captures_constraints {
  my ($self, $c, $captures) = @_;
  my @captures = @{$captures||[]};

  # Match is positive if you don't have any.
  return 1 unless $self->has_captures_constraints;

  if(
    $self->captures_constraints_count == 1 &&
    (
      $self->captures_constraints->[0]->is_a_type_of('Ref') ||
      $self->captures_constraints->[0]->is_a_type_of('ClassName')
    )
  ) {
    return $self->captures_constraints->[0]->check($captures);
  } else {
    for my $i(0..$#captures) {
      $self->captures_constraints->[$i]->check($captures[$i]) || return 0;
    }
    return 1;
    }

}


sub compare {
    my ($a1, $a2) = @_;
    return $a1->normalized_arg_number <=> $a2->normalized_arg_number;
}

sub scheme {
  return exists $_[0]->attributes->{Scheme} ? $_[0]->attributes->{Scheme}[0] : undef;
}

sub list_extra_info {
  my $self = shift;
  return {
    Args => $self->normalized_arg_number,
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

=head2 match_captures_constraints ($c, \@captures);

Does the \@captures given match any constraints (if any constraints exist).  Returns
true if you ask but there are no constraints.

=head2 match_args($c, $args)

Does the Args match or not?

=head2 resolve_type_constraint

Tries to find a type constraint if you have on on a type constrained method.

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


