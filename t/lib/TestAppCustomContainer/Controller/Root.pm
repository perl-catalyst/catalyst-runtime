package TestAppCustomContainer::Controller::Root;
use Moose;
BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub index : Default {
    my ($self, $c) = @_;
    $c->res->body('foo');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
