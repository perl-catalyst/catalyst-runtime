package TestPath::Controller::Four;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub four :Path('') :Args() {
    my ( $self, $c ) = @_;
    $c->response->body( 'OK' );
}

__PACKAGE__->meta->make_immutable;