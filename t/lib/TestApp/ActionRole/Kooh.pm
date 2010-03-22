package TestApp::ActionRole::Kooh;

use Moose::Role;

use namespace::autoclean;

after execute => sub {
    my ($self, $controller, $c) = @_;
    $c->response->header('X-Affe' => 'Tiger');
};

1;
