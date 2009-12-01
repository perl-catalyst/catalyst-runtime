package TestAppPluginWithConstructor::Controller::Root;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub foo : Local {
    my ($self, $c) = @_;
    $c->res->body('foo');
}

1;
