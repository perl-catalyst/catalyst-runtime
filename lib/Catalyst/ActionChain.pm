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

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
