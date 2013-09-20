use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Catalyst::Test 'TestApp';

ok( request('/body_semipredicate')->is_success );

done_testing;
