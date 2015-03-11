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
    is => 'rw',
    lazy => 1,
    builder=>'_build_number_of_args',
);

has ['preargs', 'postargs'] => (is => 'rw', default => sub { [] } );


  sub _build_number_of_args {
    my $self = shift;
    my @arg_protos = @{$self->attributes->{Args}||[]};

    my @args = ();
    my ($preany, $any, $postany) = (0,0,0);
    for (0 .. $#arg_protos) {
        if ( defined( $arg_protos[$_] ) && looks_like_number( $arg_protos[$_] ) ) {
            push( @args, 0 + $arg_protos[$_] );
            $preany += $arg_protos[$_];
        }
        elsif ( defined $arg_protos[$_] ) {
            my $constraint = Moose::Util::TypeConstraints::find_or_parse_type_constraint($arg_protos[$_]) or die "$arg_protos[$_] is not a constraint!";
            push(@args, $constraint);
            $preany += 1;
        }
        else {
            $any = 1;
            last;
        }
    }

    my @postargs = ();
    if ($any) {
        for (reverse(0 .. $#arg_protos)) {
            if ( defined( $arg_protos[$_] ) && looks_like_number( $arg_protos[$_] ) ) {
                push( @postargs, 0 + $arg_protos[$_] );
                $postany += $arg_protos[$_];
            }
            elsif ( defined $arg_protos[$_] ) {
                my $constraint = Moose::Util::TypeConstraints::find_or_parse_type_constraint($arg_protos[$_]) or die "$arg_protos[$_] is not a constraint!";
                push(@postargs, $constraint);
                $postany += 1;
            }
            else {
                last;
            }
        }
    }
    warn "$preany, $any, $postany";
    $self->preargs([@args]);
    $self->postargs([@postargs]);

    return $any ? undef : $preany;
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

    return 1 unless exists $self->attributes->{Args};

    my $number_of_args = $self->number_of_args;
    my @args = @{ $c->req->args };

    warn "number args = ${\($number_of_args // '*ANY*')} for ${\$self->name}";

    if(    ( $number_of_args  && scalar( @args ) == $number_of_args )
        || ( !defined($number_of_args) && scalar( @args ) >= (@{$self->preargs} + @{$self->postargs}) )
    ) {
        # For each *pre any*
        for my $constraint(@{$self->preargs}) {
            $self->check_args_contraint(\@args, $constraint) or return 0;
        }

        # Reverse remained (after pre any constraints checking) @args
        @args = reverse @args;
        # ...and check for post any
        for my $constraint(@{$self->postargs}) {
            $self->check_args_contraint(\@args, $constraint) or return 0;
        }
      return 1;
    } else {
      return 0;
    }
}

sub check_args_contraint {
    my ($self, $args, $constraint) = @_;

    if (ref $constraint eq 'Moose::Meta::TypeConstraint') {
        return !!($constraint->check(splice(@{$args}, 0, 1)));
    }
    elsif (!ref $constraint) {
        return 0 if @{$args} < $constraint;
        splice(@{$args}, 0, $constraint);
        return 1;
    }

    return 0;
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
