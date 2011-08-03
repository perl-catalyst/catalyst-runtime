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

__PACKAGE__->meta->make_immutable;
no Moose;
1;
