package Catalyst::ActionChain;

use strict;
use base qw/Catalyst::Action/;

__PACKAGE__->mk_accessors(qw/chain/);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to execute to invoke the encapsulated action coderef
    '&{}' => sub { my $self = shift; sub { $self->execute(@_); }; },

    # Make general $stuff still work
    fallback => 1,

);

=head1 NAME

Catalyst::ActionChain - Chain of Catalyst Actions

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This class represents a chain of Catalyst Actions. It behaves exactly like
the action at the *end* of the chain except on dispatch it will execute all
the actions in the chain in order.

=head1 METHODS

=head2 chain

Accessor for the action chain; will be an arrayref of the Catalyst::Action
objects encapsulated by this chain.

=head2 dispatch( $c )

Dispatch this action chain against a context; will dispatch the encapsulated
actions in order.

=cut

sub dispatch {
    my ( $self, $c ) = @_;
    my @captures = @{$c->req->captures||[]};
    my @chain = @{ $self->chain };
    my $last = pop(@chain);
    foreach my $action ( @chain ) {
        my @args;
        if (my $cap = $action->attributes->{Captures}) {
          @args = splice(@captures, 0, $cap->[0]);
        }
        local $c->request->{arguments} = \@args;
        $action->dispatch( $c );
    }
    $last->dispatch( $c );
}

=head2 from_chain( \@actions )

Takes a list of Catalyst::Action objects and constructs and returns a
Catalyst::ActionChain object representing a chain of these actions

=cut

sub from_chain {
    my ( $self, $actions ) = @_;
    my $final = $actions->[-1];
    return $self->new({ %$final, chain => $actions });
}

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
