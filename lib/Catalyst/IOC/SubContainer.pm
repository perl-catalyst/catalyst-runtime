package Catalyst::IOC::SubContainer;
use Bread::Board;
use Moose;
use Catalyst::IOC::BlockInjection;

extends 'Bread::Board::Container';

has default_component => (
    isa => 'Str|Undef',
    is  => 'ro',
    required => 0,
);

sub get_component {
    my ( $self, $name, @args ) = @_;

    return $self->resolve(
        service    => $name,
        parameters => { accept_context_args => \@args },
    );
}

sub get_component_regexp {
    my ( $self, $query, $c, @args ) = @_;

    my @result = map {
        $self->get_component( $_, $c, @args )
    } grep { m/$query/ } $self->get_service_list;

    return @result;
}

# FIXME: not the best name for a sub
sub make_single_default {
    my ( $self ) = @_;

    my @complist = $self->get_service_list;

    $self->default_component( shift @complist )
        if !$self->default_component && scalar @complist == 1;
}

1;

__END__

=pod

=head1 NAME

Catalyst::IOC::SubContainer - Container for models, controllers and views

=head1 METHODS

=head2 get_component

=head2 get_component_regexp

=head2 make_single_default

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
