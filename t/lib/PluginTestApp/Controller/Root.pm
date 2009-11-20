package PluginTestApp::Controller::Root;
use Test::More;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub compile_time_plugins : Local {
    my ( $self, $c ) = @_;

    isa_ok $c->application, 'Catalyst::Plugin::Test::Plugin';
    isa_ok $c->application, 'TestApp::Plugin::FullyQualified';

    can_ok $c, 'registered_plugins';
    $c->application->_test_plugins;

    $c->res->body("ok");
}

1;
