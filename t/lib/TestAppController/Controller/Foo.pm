package TestAppController::Controller::Foo;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller' };

has foo => (
    isa => 'Str',
    is  => 'ro',
    default => 'bar',
);

sub test_controller :Local {
    my ( $self, $c ) = @_;

    $c->res->body( $c->controller->foo );
}

__PACKAGE__->meta->make_immutable;

1;
