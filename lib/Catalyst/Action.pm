package Catalyst::Action;

use strict;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/code namespace reverse/);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to encapsulated action coderef
    '&{}' => sub { shift->{code} },

);

=head1 NAME

Catalyst::Action - Catalyst Action

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item code

=item execute

=cut

sub execute {    # Execute ourselves against a context
    my ( $self, $c ) = @_;
    return $c->execute( $self->namespace, $self );
}

=item namespace

=item reverse

=item new

=cut

sub new {        # Dumbass constructor
    my ( $class, $attrs ) = @_;
    return bless { %{ $attrs || {} } }, $class;
}

=back

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
