package Catalyst::ActionRole::Zoo;

use Moose::Role;
use namespace::clean -except => [ 'meta' ];

after execute => sub {
    my ($self, $controller, $c) = @_;
    $c->response->body(__PACKAGE__);
};

1;
