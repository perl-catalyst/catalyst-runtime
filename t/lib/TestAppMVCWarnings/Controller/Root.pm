package TestAppMVCWarnings::Controller::Root;
use Moose;
BEGIN { extends 'Catalyst::Controller' };

__PACKAGE__->config->{namespace} = '';

sub index :Path Args() {}

sub model : Local {
    my ($self, $c) = @_;
    $c->model; # Cause model lookup and ergo warning we are testing.
    $c->res->body('foo');
}

sub view : Local {
    my ($self, $c) = @_;
    $c->view; # Cause view lookup and ergo warning we are testing.
    $c->res->body('bar');
}

1;
