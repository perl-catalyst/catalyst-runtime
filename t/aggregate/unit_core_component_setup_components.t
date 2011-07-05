use strict;
use warnings;
use Test::More;
use Moose::Meta::Class;

Moose::Meta::Class->create( TestAppComponents => (
    superclasses => ['Catalyst'],
    methods      => {
        locate_components => \&overriden_locate_components,
    },
));

TestAppComponents->components( {} );

# this is so TestAppComponents->container will work
TestAppComponents->setup_config;

# this is so TestAppComponents->log->warn will work
TestAppComponents->setup_log;

my @comps = TestAppComponents->locate_components;

for my $component (@comps) {
    Moose::Meta::Class->create( $component => (
        superclasses => ['Catalyst::Component'],
    ));
}

{
    my @loaded_comps;
    my $warnings = 0;

    no warnings 'redefine', 'once';

    local *Catalyst::Log::warn = sub { $warnings++ };
    local *Catalyst::Utils::ensure_class_loaded = sub { my $class = shift; push @loaded_comps, $class; };

    eval { TestAppComponents->setup_components };

    ok( !$@, "setup_components doesnt die" );
    ok( $warnings, "it warns about deprecated names" );
    is_deeply( \@comps, \@loaded_comps, 'all components loaded' );
}

my @comps_copy  = @comps;

my @controllers = map { s/^TestAppComponents::(C|Controller):://; $_; } @comps_copy[0..7];
my @models      = map { s/^TestAppComponents::(M|Model):://; $_; }      @comps_copy[8..15];
my @views       = map { s/^TestAppComponents::(V|View):://; $_; }       @comps_copy[16..23];
my $container   = TestAppComponents->container;

is_deeply(
    [ sort $container->get_sub_container('controller')->get_service_list ],
    [ sort @controllers ],
    'controllers are in the container',
);

is_deeply(
    [ sort TestAppComponents->controllers ],
    [ sort @controllers ],
    'controllers are listed correctly by $c->controllers()',
);

is_deeply(
    [ sort $container->get_sub_container('model')->get_service_list ],
    [ sort @models ],
    'models are in the container',
);

is_deeply(
    [ sort TestAppComponents->models ],
    [ sort @models ],
    'models are listed correctly by $c->models()',
);

is_deeply(
    [ sort $container->get_sub_container('view')->get_service_list ],
    [ sort @views ],
    'views are in the container',
);

is_deeply(
    [ sort TestAppComponents->views ],
    [ sort @views ],
    'views are listed correctly by $c->views()',
);

is_deeply(
    [ sort keys %{ TestAppComponents->components } ],
    [ sort @comps ],
    'all components are in the components accessor'
);

done_testing();

sub overriden_locate_components {
    my @comps;
    push @comps, "TestAppComponents::$_" for qw/
        C::Bar
        C::Foo::Bar
        C::Foo::Foo::Bar
        C::Foo::Foo::Foo::Bar
        Controller::Bar::Bar::Bar::Foo
        Controller::Bar::Bar::Foo
        Controller::Bar::Foo
        Controller::Foo
        M::Bar
        M::Foo::Bar
        M::Foo::Foo::Bar
        M::Foo::Foo::Foo::Bar
        Model::Bar::Bar::Bar::Foo
        Model::Bar::Bar::Foo
        Model::Bar::Foo
        Model::Foo
        V::Bar
        V::Foo::Bar
        V::Foo::Foo::Bar
        V::Foo::Foo::Foo::Bar
        View::Bar::Bar::Bar::Foo
        View::Bar::Bar::Foo
        View::Bar::Foo
        View::Foo
    /;
    return @comps;
}
