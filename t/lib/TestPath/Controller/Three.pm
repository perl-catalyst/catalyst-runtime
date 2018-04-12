package TestPath::Controller::Three;
use Moose;
use namespace::clean -except => [ 'meta' ];

BEGIN { extends 'Catalyst::Controller' }

sub three :Path('') {
    my ( $self, $c ) = @_;
    $c->response->body( 'OK' );
}

__PACKAGE__->meta->make_immutable;
