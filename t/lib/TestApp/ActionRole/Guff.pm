package TestApp::ActionRole::Guff;

use Moose::Role;

after execute => sub {
    my ($self, $controller, $c) = @_;
    $c->response->body(__PACKAGE__);
};

1;
