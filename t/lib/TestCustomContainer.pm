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

    is($app->config->{container_class}, $self->container_class, 'config is set properly');
    isa_ok($app->container, $self->container_class, 'and container isa our container class');

    # RequestLifeCycle
    {
        # just to be sure the app is not broken
        ok(my ($res, $ctx) = ctx_request('/'), 'request');
        ok($res->is_success, 'request 2xx');
        is($res->content, 'foo', 'content is expected');

        ok(my $model = $ctx->container->get_sub_container('model')->resolve(service => 'RequestLifeCycle', parameters => { ctx => $ctx, accept_context_args => [$ctx] } ), 'fetching RequestLifeCycle');
        isa_ok($model, 'TestAppCustomContainer::Model::RequestLifeCycle');

        ok(my $model2 = $ctx->model('RequestLifeCycle'), 'fetching RequestLifeCycle again');
        is($model, $model2, 'object is not recreated during the same request');

        # another request
        my ($res2, $ctx2) = ctx_request('/');
        ok($model2 = $ctx2->model('RequestLifeCycle'), 'fetching RequestLifeCycle again');
        isnt($model, $model2, 'object is recreated in a different request');
    }

    # SingletonLifeCycle
    {
        # already tested, I only need the $ctx
        my ($res, $ctx) = ctx_request('/');

        ok(my $model = $ctx->container->get_sub_container('model')->resolve(service => 'SingletonLifeCycle', parameters => { ctx => $ctx, accept_context_args => [$ctx] } ), 'fetching SingletonLifeCycle');
        isa_ok($model, 'TestAppCustomContainer::Model::SingletonLifeCycle');

        ok(my $model2 = $ctx->model('SingletonLifeCycle'), 'fetching SingletonLifeCycle again');
        is($model, $model2, 'object is not recreated during the same request');

        # another request
        my ($res2, $ctx2) = ctx_request('/');
        ok($model2 = $ctx2->model('SingletonLifeCycle'), 'fetching SingletonLifeCycle again');
        is($model, $model2, 'object is not recreated in a different request');
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
