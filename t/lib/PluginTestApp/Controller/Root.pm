package PluginTestApp::Controller::Root;
use Test::More;

use base 'Catalyst::Controller';

#use Catalyst qw(
#        Test::Plugin
#        +TestApp::Plugin::FullyQualified
#        );

__PACKAGE__->config->{namespace} = '';

sub compile_time_plugins : Local {
    my ( $self, $c ) = @_;

    isa_ok $c, 'Catalyst::Plugin::Test::Plugin';
    isa_ok $c, 'TestApp::Plugin::FullyQualified';

    can_ok $c, 'registered_plugins';
    $c->_test_plugins;

    $c->res->body("ok");
}

sub run_time_plugins : Local {
    my ( $self, $c ) = @_;

    $c->_test_plugins;
    my $faux_plugin = 'Faux::Plugin';

# Trick perl into thinking the plugin is already loaded
    $INC{'Faux/Plugin.pm'} = 1;

    ref($c)->plugin( faux => $faux_plugin );

    isa_ok $c, 'Catalyst::Plugin::Test::Plugin';
    isa_ok $c, 'TestApp::Plugin::FullyQualified';
    ok !$c->isa($faux_plugin),
    '... and it should not inherit from the instant plugin';
    can_ok $c, 'faux';
    is $c->faux->count, 1, '... and it should behave correctly';
    is_deeply [ $c->registered_plugins ],
    [
        qw/Catalyst::Plugin::Test::Plugin
        Faux::Plugin
        TestApp::Plugin::FullyQualified/
        ],
    'registered_plugins() should report all plugins';
    ok $c->registered_plugins('Faux::Plugin'),
    '... and even the specific instant plugin';

    $c->res->body("ok");
}

1;
