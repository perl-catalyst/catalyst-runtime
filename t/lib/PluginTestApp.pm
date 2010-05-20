package PluginTestApp;
use Test::More;

use Catalyst (
    'Test::Plugin',
    '+TestApp::Plugin::FullyQualified',
    (eval { require MooseX::Role::Parameterized; 1 }
        ? ('+TestApp::Plugin::ParameterizedRole' => { method_name => 'affe' })
        : ()),
);

sub _test_plugins {
    my $c = shift;
    is_deeply [ $c->registered_plugins ],
    [
        qw/Catalyst::Plugin::Test::Plugin
        TestApp::Plugin::FullyQualified/
        ],
    '... and it should report the correct plugins';
    ok $c->registered_plugins('Catalyst::Plugin::Test::Plugin'),
    '... or if we have a particular plugin';
    ok $c->registered_plugins('Test::Plugin'),
    '... even if it is not fully qualified';
    ok !$c->registered_plugins('No::Such::Plugin'),
    '... and it should return false if the plugin does not exist';
}

__PACKAGE__->setup;
