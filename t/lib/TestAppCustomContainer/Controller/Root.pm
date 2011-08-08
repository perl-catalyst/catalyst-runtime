package TestAppCustomContainer::Controller::Root;
use Moose;
BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub container_class :Local {
    my ($self, $c) = @_;
    $c->res->body($c->config->{container_class});
}

sub container_isa :Local {
    my ($self, $c) = @_;
    $c->res->body(ref $c->container);
}

sub get_model_bar :Local {
    my ($self, $c) = @_;
    $c->res->body(ref $c->model('Bar'));
}

sub get_model_baz :Local {
    my ($self, $c) = @_;
    $c->res->body(ref $c->model('Baz'));
}

sub get_model_foo :Local {
    my ($self, $c) = @_;
    $c->res->body(ref $c->model('Foo'));
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
