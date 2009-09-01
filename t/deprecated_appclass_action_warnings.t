use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Catalyst::Test 'DeprecatedActionsInAppClassTestApp';

plan tests => 2;

ok( my $response = request('http://localhost/foo'), 'Request' );
ok( $response->is_success, 'Response Successful 2xx' );
