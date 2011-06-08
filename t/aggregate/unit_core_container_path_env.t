use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 3;

$ENV{ TESTAPPCONTAINER_CONFIG } = 'test.perl';

use_ok 'Catalyst::Test', 'TestAppContainer';

ok my ( $res, $c ) = ctx_request( '/' ), 'context object';

is_deeply $c->container->resolve( service => 'config_path' ), [ qw( test.perl perl ) ], 'path is "test.perl"';
