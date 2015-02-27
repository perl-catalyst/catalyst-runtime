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
use List::MoreUtils 'uniq';
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



# Compare rules to future compare sort order.
# HASH with rules:
# (
#   RULE => DEFINITION
# )
# RULE := string
# DEFINITION:= -1 | 0 | 1 | coderef
#
# Default rule (no sorting): * => 0
#
# When DEFINITION is integer, then RULE is being used
# as action attribute key to get values:
#   $self->attributes->{RULE} * DEFINITION
#
# When DEFINITION is coderef, then rule value is
# result of calling DEFINITION->($self)

sub compare_rules {
    return (
        '*', => 0,
        Args => sub {
            my $self = shift;

            my ($val) =  @{ $self->attributes->{Args} || [] };

            return looks_like_number($val) ? $val : ~0;
        },
    );
}

# Rules keys. Order of keys is equal to compare order checks
sub compare_keys {
    return ('Args');
}

# rule definition for specified rule
sub _compare_rule {
    my ($self, $attr) = @_;

    my %rules = $self->compare_rules;

    return ( $rules{$attr} // $rules{'*'} );
}

# rule value for specified rule
sub _compare_value {
    my ($self, $attr) = @_;

    my $rule = $self->_compare_rule($attr);

    if ( ref $rule eq 'CODE' ) {
        return $rule->($self);
    }
    else {
        return $rule * @{ $self->attributes->{$attr} || [] };
    }
}


sub compare {
    my ($a1, $a2) = @_;

    my %cmp = (
        a1 => {},
        a2 => {},
    );

    my @a1keys = $a1->compare_keys;
    my @a2keys = $a2->compare_keys;

    for my $attr (uniq(@a1keys, @a2keys)) {
        $cmp{a1}{$attr} = $a1->_compare_value($attr) * @a1keys;
        $cmp{a2}{$attr} = $a2->_compare_value($attr) * @a2keys;
    }

    my $cmp = 0;

    $cmp ||= $cmp{a1}{$_} <=> $cmp{a2}{$_} for uniq(@a1keys, @a2keys);

    return $cmp;
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
