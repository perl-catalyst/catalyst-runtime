use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 18;
use Catalyst::Test 'TestApp';
use HTTP::Request::Common;

my $content_length;

foreach my $method (qw(HEAD GET)) {
    my $expected = join( ', ', 1 .. 10 );

    my $request = HTTP::Request::Common->can($method)
        ->( 'http://localhost/engine/response/headers/one' );

    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->code, 200, 'Response Code' );
    is( $response->header('X-Catalyst-Action'),
        'engine/response/headers/one', 'Test Action' );
    is( $response->header('X-Header-Catalyst'),
        'Cool', 'Response Header X-Header-Catalyst' );
    is( $response->header('X-Header-Cool'),
        'Catalyst', 'Response Header X-Header-Cool' );
    is( $response->header('X-Header-Numbers'),
        $expected, 'Response Header X-Header-Numbers' );

    use bytes;
    if ( $method eq 'HEAD' ) {
        $content_length = $response->header('Content-Length');
        ok( $content_length > 0, 'Response Header Content-Length' );
        is( length($response->content),
            0,
            'HEAD method content is empty' );
    }
    elsif ( $method eq 'GET' ) {
        is( $response->header('Content-Length'),
            $content_length, 'Response Header Content-Length' )
            or diag $response->content;
        is( length($response->content),
            $response->header('Content-Length'),
            'GET method content' );
    }
}
