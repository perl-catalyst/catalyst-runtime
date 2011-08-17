package TestCustomContainer;
use Moose;
use namespace::autoclean;
use Test::More;

has app_name => (
    is => 'ro',
    isa => 'Str',
    default => 'TestAppCustomContainer',
);

has container_class => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has sugar => (
    is => 'ro',
    isa => 'Int',
);

# Reason for this class:
# I wanted have a set of tests that would test both the sugar version of the
# container, as the sugar-less. I figured I shouldn't just copy and paste
# the tests. So after struggling for hours to find a way to test twice
# against the same TestApp using only one file, I decided to break it
# into a separate class (this one), and call it at
#           -  live_container_custom_container_sugar.t and
#           -  live_container_custom_container_nosugar.t
# setting only the sugar attribute.

sub BUILD {
    my $self = shift;
    my $app  = $self->app_name;

    $ENV{TEST_APP_CURRENT_CONTAINER} = $self->container_class;

    require Catalyst::Test;
    Catalyst::Test->import($app);

    is($app->config('container_class'), $self->container_class, 'config is set properly');
    isa_ok($app->container, $self->container_class, 'and container isa our container class');

    {
        # DefaultSetup ACCEPT_CONTEXT called - total: 1
        ok(my ($res, $c) = ctx_request('/'), 'request');
        ok($res->is_success, 'request 2xx');
        is($res->content, 'foo', 'content is expected');

        ok(my $baz = $c->container->get_sub_container('model')->resolve(service => 'RequestLifeCycle', parameters => { ctx => $c, accept_context_args => [$c] } ), 'fetching RequestLifeCycle');
        isa_ok($baz, 'TestAppCustomContainer::Model::RequestLifeCycle');
        is($baz->accept_context_called, 1, 'ACCEPT_CONTEXT called');
        isa_ok($baz->foo, 'TestAppCustomContainer::Model::Foo', 'RequestLifeCycle got Foo ok');

        # DefaultSetup ACCEPT_CONTEXT called - total: 2
        ok(get('/get_model_baz'), 'another request');
        is($baz->accept_context_called, 1, 'ACCEPT_CONTEXT not called again (instance per context)');
#        is($foo->baz_got_it, 2, 'Baz accessed Foo again');
    }

    {
        # DefaultSetup ACCEPT_CONTEXT called - total: 3
        ok(my ($res, $c) = ctx_request('/get_model_bar'), 'request');
        ok($res->is_success, 'request 2xx');
        is($res->content, 'TestAppCustomContainer::Model::Bar', 'content is expected');

        ok(my $bar = $c->container->get_sub_container('component')->resolve(service => 'model_Bar'), 'fetching Bar');
        isa_ok($bar, 'TestAppCustomContainer::Model::Bar');

        # FIXME - is this expected behavior?
        is($bar->accept_context_called, 1, 'ACCEPT_CONTEXT called');
        isa_ok($bar->foo, 'TestAppCustomContainer::Model::Foo', 'Bar got Foo ok');

        # DefaultSetup ACCEPT_CONTEXT *not* called - total: 3
        ok(get('/get_model_bar'), 'another request');
        is($bar->accept_context_called, 1, 'ACCEPT_CONTEXT not called again (lifecycle is Singleton)');
#        is($foo->bar_got_it, 1, 'Bar didn\'t access Foo again');
    }

    {
        # DefaultSetup ACCEPT_CONTEXT called - total: 4
        ok(my ($res, $c) = ctx_request('/get_model_foo'), 'request');
        ok($res->is_success, 'request 2xx');
        is($res->content, 'TestAppCustomContainer::Model::Foo', 'content is expected');

#        ok(my $foo = $c->container->get_sub_container('component')->resolve(service => 'model_Foo'), 'fetching Foo');
#        isa_ok($foo, 'TestAppCustomContainer::Model::Foo');
#        is($foo->accept_context_called, 4, 'ACCEPT_CONTEXT called');
#        is($foo->bar_got_it, 1, 'Bar accessed Foo once');
#        is($foo->baz_got_it, 2, 'Baz accessed Foo twice');
    }

    done_testing;
}

sub _build_container_class {
    my $self = shift;

    my $sugar = $self->sugar ? '' : 'No';

    return $self->app_name . "::${sugar}SugarContainer";
}

__PACKAGE__->meta->make_immutable;

1;
