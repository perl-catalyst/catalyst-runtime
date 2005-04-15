#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 10;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;
use URI;

{
    my $creq;

    my $request = GET( 'http://localhost/dump/request', 
        'User-Agent'   => 'MyAgen/1.0',
        'X-Whats-Cool' => 'Catalyst'
    );
 
    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    isa_ok( $creq, 'Catalyst::Request' );
    isa_ok( $creq->headers, 'HTTP::Headers', 'Catalyst::Request->headers' );
    is( $creq->header('X-Whats-Cool'), $request->header('X-Whats-Cool'), 'Catalyst::Request->header X-Whats-Cool' );
    is( $creq->header('User-Agent'), $request->header('User-Agent'), 'Catalyst::Request->header User-Agent' );

    my $host = sprintf( '%s:%d', $request->uri->host, $request->uri->port );
    is( $creq->header('Host'), $host, 'Catalyst::Request->header Host' );
}
