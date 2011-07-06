package Catalyst::Service::WithContext;
use Moose::Role;

use Bread::Board::Types;

with 'Bread::Board::Service';

has accept_context_sub => (
    is => 'ro',
    isa => 'Str',
    default => 'ACCEPT_CONTEXT',
);

around 'get' => sub {
    my ( $orig, $self, %params ) = @_;

    my $context = delete $params{context};

    my $instance = $self->$orig(%params);
    my $ac_sub   = $self->accept_context_sub;

    if ( $instance->can($ac_sub) ) {
        return $instance->$ac_sub( @$context );
    }

    return $instance;
};

no Moose::Role;
1;

__END__

=pod

=head1 NAME

Catalyst::Service::WithContext

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<accept_context_sub>

=item B<get>

=back

=head1 AUTHOR

André Walker

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
