#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;
use Catalyst::Test 'TestApp';

ok( my $response = request('http://localhost/loop_test'), 'Request' );
ok( $response->is_success, 'Response Successful 2xx' );
ok( $response->header('X-Class-Forward-Test-Method'), 'Loop OK' );
