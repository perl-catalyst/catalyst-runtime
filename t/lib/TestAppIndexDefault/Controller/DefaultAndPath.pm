package TestAppIndexDefault::Controller::DefaultAndPath;

use base 'Catalyst::Controller';

sub default : Private {
    my ($self, $c) = @_;
    $c->res->body('default');
}

sub path_one_arg : Path('/') Args(1) {
    my ($self, $c) = @_;
    $c->res->body('path_one_arg');
}

1;
