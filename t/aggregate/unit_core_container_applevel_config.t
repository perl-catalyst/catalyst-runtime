#!perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use TestAppContainer;

my $applevel_config = TestAppContainer->container->resolve(service => 'config')->{applevel_config};

ok($applevel_config, 'applevel_config exists in the container');
is($applevel_config, 'foo', 'and has the correct value');

$applevel_config = TestAppContainer->config->{applevel_config};

ok($applevel_config, 'applevel_config exists in the config accessor');
is($applevel_config, 'foo', 'and has the correct value');

my $home = TestAppContainer->container->resolve(service => 'config')->{home};
ok( $home );

$home = TestAppContainer->config->{home};
ok( $home );

done_testing;
