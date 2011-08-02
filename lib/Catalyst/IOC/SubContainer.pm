package Catalyst::IOC::SubContainer;
use Bread::Board;
use Moose;

extends 'Bread::Board::Container';

has default_component => (
    isa      => 'Str|Undef',
    is       => 'ro',
    builder  => '_build_default_component',
    lazy     => 1,
);

sub _build_default_componentt {
    my ( $self ) = @_;

    my @complist = $self->get_service_list;

    scalar @complist == 1 ? $complist[0] : undef;
}


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

1;

__END__

=pod

=head1 NAME

Catalyst::IOC::SubContainer - Container for models, controllers and views

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 get_component

Gets the service of the container for the searched component. Also executes
the ACCEPT_CONTEXT sub in the component, if it exists.

=head2 get_component_regexp

Gets all components from container that match a given regexp.

=head2 make_single_default

If the container has only one component, and no default has been defined,
this method makes that one existing service the default.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
