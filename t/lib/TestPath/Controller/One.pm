package TestPath::Controller::One;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub one :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'OK' );
}

__PACKAGE__->meta->make_immutable;