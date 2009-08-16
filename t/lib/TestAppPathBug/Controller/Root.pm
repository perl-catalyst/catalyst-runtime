package TestAppPathBug::Controller::Root;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub foo : Path {
    my ( $self, $c ) = @_;
    $c->res->body( 'This is the foo method.' );
}

1;
