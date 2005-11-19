package Catalyst::ActionContainer;

use strict;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/part actions/);

use overload (

    # Stringify to path part for tree search
    q{""} => sub { shift->{part} },

);

=head1 NAME

Catalyst::ActionContainer - Catalyst Action Container

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 get_action

=cut

sub get_action {
    my ( $self, $name ) = @_;
    return $self->actions->{$name} if defined $self->actions->{$name};
    return;
}

=head2 actions

=head2 part

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
