package Catalyst::Action;

use strict;
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw/class namespace reverse attributes name code/);

use overload (

    # Stringify to reverse for debug output etc.
    q{""} => sub { shift->{reverse} },

    # Codulate to encapsulated action coderef
    '&{}' => sub { shift->{code} },

    # Make general $stuff still work
    fallback => 1,

);

=head1 NAME

Catalyst::Action - Catalyst Action

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 attributes

=head2 class

=head2 code

=head2 execute

=cut

sub execute {    # Execute ourselves against a context
    my ( $self, $c ) = @_;
    local $c->namespace = $self->namespace;
    return $c->execute( $self->class, $self );
}

=head2 match

=cut

sub match {
    my ( $self, $c ) = @_;
    return 1 unless exists $self->attributes->{Args};
    return scalar(@{$c->req->args}) == $self->attributes->{Args}[0];
}

=head2 namespace

=head2 reverse

=head2 name

=head1 AUTHOR

Matt S. Trout

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
