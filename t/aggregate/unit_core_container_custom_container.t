use strict;
use warnings;
use Test::More;

# first, test if it loads Catalyst::Container when
# no custom container exists
{
    package ContainerTestApp;
    use Moose;
    extends 'Catalyst';

    __PACKAGE__->setup_config();
    __PACKAGE__->setup_log();
}

my $container = ContainerTestApp->container;

# 'is' instead of 'isa_ok', because I want it to be only Catalyst::Container
# and not some subclass
is( ref $container, 'Catalyst::Container', 'The container is Catalyst::Container, not a subclass');

# now, check if it loads the subclass when it exists
{
    package CustomContainerTestApp::Container;
    use Moose;
    extends 'Catalyst::Container';

    sub my_custom_method { 1 }
}

{
    package CustomContainerTestApp;
    use Moose;
    BEGIN { extends 'Catalyst' };

    __PACKAGE__->setup_config();
}

$container = CustomContainerTestApp->container;

isa_ok($container, 'CustomContainerTestApp::Container');
isa_ok($container, 'Catalyst::Container');
can_ok($container, 'my_custom_method');
ok( eval { $container->my_custom_method }, 'executes the method correctly');

done_testing;

