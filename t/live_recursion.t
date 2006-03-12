#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;
use Catalyst::Test 'TestApp';

ok( my $response = request('http://localhost/recursion_test'), 'Request' );
ok( !$response->is_success, 'Response Not Successful' );
is( $response->header('X-Catalyst-Error'), 'Deep recursion detected calling "/recursion_test"', 'Deep Recursion Detected' );
