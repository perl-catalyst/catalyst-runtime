use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 9;
use Catalyst::Test 'TestPath';


{
    ok( my $response = request('http://localhost/one'), 'Request' );
    ok( $response->is_success, '"Path" - Response Successful 2xx' );
    is( $response->content, 'OK', '"Path" - Body okay' );
}
{
    ok( my $response = request('http://localhost/two'), 'Request' );
    ok( $response->is_success, '"Path()" - Response Successful 2xx' );
    is( $response->content, 'OK', '"Path()" - Body okay' );
}
{
    ok( my $response = request('http://localhost/three'), 'Request' );
    ok( $response->is_success, '"Path(\'\')" - Response Successful 2xx' );
    is( $response->content, 'OK', '"Path(\'\')" - Body okay' );
}


