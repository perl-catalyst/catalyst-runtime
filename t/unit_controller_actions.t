use strict;
use warnings;
use Test::More tests => 4;

use Catalyst ();
{
    package TestController;
    use Moose;
    BEGIN { extends 'Catalyst::Controller' }

    sub action : Local {}

    sub foo : Path {}

    no Moose;
}

my $mock_app = Class::MOP::Class->create_anon_class( superclasses => ['Catalyst'] );
my $app = $mock_app->name->new;
my $controller = TestController->new($app, {actions => { foo => { Path => '/some/path' }}});

ok $controller->can('_controller_actions');
is_deeply $controller->_controller_actions => { foo => { Path => '/some/path' }};
is_deeply $controller->{actions} => { foo => { Path => '/some/path' }}; # Back compat.
is_deeply [ sort grep { ! /^_/ } $controller->get_action_methods ], [sort qw/action foo/];

