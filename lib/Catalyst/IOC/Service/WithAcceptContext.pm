package Catalyst::IOC::Service::WithAcceptContext;
use Moose::Role;

with 'Bread::Board::Service';

has accept_context_sub => (
    is => 'ro',
    isa => 'Str',
    default => 'ACCEPT_CONTEXT',
);

around 'get' => sub {
    my ( $orig, $self, %params ) = @_;

    my $accept_context_args = delete $params{accept_context_args};

    my $instance = $self->$orig(%params);
    my $ac_sub   = $self->accept_context_sub;

    if ( $accept_context_args && $instance->can($ac_sub) ) {
        return $instance->$ac_sub( @$accept_context_args );
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

=over

=item B<accept_context_sub>

=item B<get>

=back

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
