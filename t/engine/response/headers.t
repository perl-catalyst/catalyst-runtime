#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 7;
use Catalyst::Test 'TestApp';


{
    my $expected = join( ', ', 1 .. 10 );

    ok( my $response = request('http://localhost/engine/response/headers/one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->code, 200, 'Response Code' );
    is( $response->header('X-Catalyst-Action'), 'engine/response/headers/one', 'Test Action' );
    is( $response->header('X-Header-Catalyst'), 'Cool', 'Response Header X-Header-Catalyst' );
    is( $response->header('X-Header-Cool'), 'Catalyst', 'Response Header X-Header-Cool' );
    is( $response->header('X-Header-Numbers'), $expected, 'Response Header X-Header-Numbers' );
}
