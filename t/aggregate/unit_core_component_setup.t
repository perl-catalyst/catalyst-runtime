package TestAppComponents;
use warnings;
use strict;
use base 'Catalyst';

sub locate_components {
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

__PACKAGE__->components( {} );

# this is so $c->container will work
__PACKAGE__->setup_config;

# this is so $c->log->warn will work
__PACKAGE__->setup_log;

for my $component (TestAppComponents->locate_components) {
    my $classname = "$component";
    eval <<COMPONENT;
package $classname;
use warnings;
use strict;
use base 'Catalyst::Component';

1;
COMPONENT
}

package main;
use strict;
use warnings;

use Test::More;

my @comps = TestAppComponents->locate_components;

{
    my @loaded_comps;
    my $warnings = 0;

    no warnings 'redefine';

    local *Catalyst::Log::warn = sub { $warnings++ };
    local *Catalyst::Utils::ensure_class_loaded = sub { my $class = shift; push @loaded_comps, $class; };

    eval { TestAppComponents->setup_components };

    ok( !$@, "setup_components doesnt die" );
    ok( $warnings, "it warns about deprecated names" );
    is_deeply( \@comps, \@loaded_comps, 'all components loaded' );
}

my @controllers = @comps[0..7];
my @models      = @comps[8..15];
my @views       = @comps[16..23];
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
