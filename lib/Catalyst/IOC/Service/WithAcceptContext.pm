package Catalyst::IOC::Service::WithAcceptContext;
use Moose::Role;

with 'Bread::Board::Service';

has accept_context_sub => (
    is => 'ro',
    isa => 'Str',
    default => 'ACCEPT_CONTEXT',
);

around 'get' => sub {
    my $orig = shift;
    my $self = shift;

    my $instance = $self->$orig(@_);

    my $accept_context_args = $self->param('accept_context_args');
    my $ac_sub = $self->accept_context_sub;

    if ( $instance->can($ac_sub) ) {
        return $instance->$ac_sub( @$accept_context_args );
    }

    return $instance;
};

no Moose::Role;
1;

__END__

=pod

=head1 NAME

Catalyst::IOC::Service::WithAcceptContext

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 accept_context_sub

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
