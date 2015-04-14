package Catalyst::ActionChain;

use Moose;
extends qw(Catalyst::Action);

has chain => (is => 'rw');
no Moose;

=head1 NAME

Catalyst::ActionChain - Chain of Catalyst Actions

=head1 SYNOPSIS

See L<Catalyst::Manual::Intro> for more info about Chained actions.

=head1 DESCRIPTION

This class represents a chain of Catalyst Actions. It behaves exactly like
the action at the *end* of the chain except on dispatch it will execute all
the actions in the chain in order.

=cut

sub dispatch {
    my ( $self, $c ) = @_;
    my @captures = @{$c->req->captures||[]};
    my @chain = @{ $self->chain };
    my $last = pop(@chain);
    foreach my $action ( @chain ) {
        my @args;
        if (my $cap = $action->number_of_captures) {
          @args = splice(@captures, 0, $cap);
        }
        local $c->request->{arguments} = \@args;
        $action->dispatch( $c );

        # break the chain if exception occurs in the middle of chain.  We
        # check the global config flag 'abort_chain_on_error_fix', but this
        # is now considered true by default, so unless someone explicitly sets
        # it to false we default it to true (if its not defined).
        my $abort = defined($c->config->{abort_chain_on_error_fix}) ?
          $c->config->{abort_chain_on_error_fix} : 1;
        return if ($c->has_errors && $abort);
    }
    $last->dispatch( $c );
}

sub from_chain {
    my ( $self, $actions ) = @_;
    my $final = $actions->[-1];
    return $self->new({ %$final, chain => $actions });
}

sub number_of_captures {
    my ( $self ) = @_;
    my $chain = $self->chain;
    my $captures = 0;

    $captures += $_->number_of_captures for @$chain;
    return $captures;
}

sub match_captures {
  my ($self, $c, $captures) = @_;
  my @captures = @{$captures||[]};

  foreach my $link(@{$self->chain}) {
    my @local_captures = splice @captures,0,$link->number_of_captures;
    return unless $link->match_captures($c, \@local_captures);
  }
  return 1;
}
sub match_captures_constraints {
  my ($self, $c, $captures) = @_;
  my @captures = @{$captures||[]};

  foreach my $link(@{$self->chain}) {
    my @local_captures = splice @captures,0,$link->number_of_captures;
    next unless $link->has_captures_constraints;
    return unless $link->match_captures_constraints($c, \@local_captures);
  }
  return 1;
}

# the scheme defined at the end of the chain is the one we use
# but warn if too many.

sub scheme {
  my $self = shift;
  my @chain = @{ $self->chain };
  my ($scheme, @more) = map {
    exists $_->attributes->{Scheme} ? $_->attributes->{Scheme}[0] : ();
  } reverse @chain;

  warn "$self is a chain with two many Scheme attributes (only one is allowed)"
    if @more;

  return $scheme;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 METHODS

=head2 chain

Accessor for the action chain; will be an arrayref of the Catalyst::Action
objects encapsulated by this chain.

=head2 dispatch( $c )

Dispatch this action chain against a context; will dispatch the encapsulated
actions in order.

=head2 from_chain( \@actions )

Takes a list of Catalyst::Action objects and constructs and returns a
Catalyst::ActionChain object representing a chain of these actions

=head2 number_of_captures

Returns the total number of captures for the entire chain of actions.

=head2 match_captures

Match all the captures that this chain encloses, if any.

=head2 scheme

Any defined scheme for the actionchain

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
