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

    $ENV{TEST_APP_CURRENT_CONTAINER} = $self->container_class;

    require Catalyst::Test;
    Catalyst::Test->import($self->app_name);

    is(get('/container_class'), $self->container_class);
    is(get('/container_isa'), $self->container_class);

    {
        ok(my ($res, $c) = ctx_request('/get_model_baz'), 'request');
        ok($res->is_success, 'request 2xx');
        is($res->content, 'TestAppCustomContainer::Model::Baz', 'content is expected');

        ok(my $baz = $c->container->get_sub_container('component')->resolve(service => 'model_Baz'), 'fetching Baz');
        isa_ok($baz, 'TestAppCustomContainer::Model::Baz');
        is($baz->accept_context_called, 1, 'ACCEPT_CONTEXT called');
        isa_ok($baz->foo, 'TestAppCustomContainer::Model::Foo', 'Baz got Foo ok');

        ok(my $foo = $c->container->get_sub_container('component')->resolve(service => 'model_Foo'), 'fetching Foo');
        isa_ok($foo, 'TestAppCustomContainer::Model::Foo');
        is($foo->baz_got_it, 1, 'Baz accessed Foo once');
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
