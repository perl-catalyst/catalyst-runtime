package Catalyst::SubContainer;
use Bread::Board;
use Moose;
use Catalyst::BlockInjection;

extends 'Bread::Board::Container';

sub get_component {
    my ( $self, $name, $args ) = @_;
    return $self->resolve( service => $name, parameters => { context => $args } );
}

1;
