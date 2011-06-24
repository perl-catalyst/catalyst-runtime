use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

$ENV{ TESTAPPCONTAINER_CONFIG_LOCAL_SUFFIX } = 'test';
use_ok 'Catalyst::Test', 'TestAppContainer';

ok my ( $res, $c ) = ctx_request( '/' ), 'context object';

is $c->container->resolve( service => 'config_local_suffix' ), 'test', 'suffix is "test"';

done_testing;
