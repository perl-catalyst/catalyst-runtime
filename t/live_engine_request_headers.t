#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 27;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;

{
    my $creq;

    my $request = GET(
        'http://localhost/dump/request',
        'User-Agent'         => 'MyAgen/1.0',
        'X-Whats-Cool'       => 'Catalyst',
        'X-Multiple'         => [ 1 .. 5 ],
        'X-Forwarded-Host'   => 'frontend.server.com',
        'X-Forwarded-For'    => '192.168.1.1, 1.2.3.4',
        # Trailing slash is intentional - tests that we don't generate
        # paths with doubled slashes
        'X-Forwarded-Path'   => '/prefix/',
        'X-Forwarded-Port'   => '12345',
        'X-Forwarded-Is-SSL' => 1,
    );
 
    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    isa_ok( $creq, 'Catalyst::Request' );
    isa_ok( $creq->headers, 'HTTP::Headers', 'Catalyst::Request->headers' );
    is( $creq->header('X-Whats-Cool'), $request->header('X-Whats-Cool'), 'Catalyst::Request->header X-Whats-Cool' );
    
    { # Test that multiple headers are joined as per RFC 2616 4.2 and RFC 3875 4.1.18

        my $excpected = '1, 2, 3, 4, 5';
        my $got       = $creq->header('X-Multiple'); # HTTP::Headers is context sensitive, "force" scalar context

        is( $got, $excpected, 'Multiple message-headers are joined as a comma-separated list' );
    }

    is( $creq->header('User-Agent'), $request->header('User-Agent'), 'Catalyst::Request->header User-Agent' );

    my $host = sprintf( '%s:%d', $request->uri->host, $request->uri->port );
    is( $creq->header('Host'), $host, 'Catalyst::Request->header Host' );

    SKIP:
    {
        if ( $ENV{CATALYST_SERVER} && $ENV{CATALYST_SERVER} !~ /127.0.0.1|localhost/ ) {
            skip "Using remote server", 12;
        }
    
        is( $creq->address, '1.2.3.4', 'X-Forwarded-For header => address()' );
        is( $creq->hostname, 'frontend.server.com', 'X-Forwarded-Host header => hostname()' );
        is( $creq->base->host, 'frontend.server.com', 'X-Forwarded-Host => base()->host()' );
        is( $creq->uri->host, 'frontend.server.com', 'X-Forwarded-Host => uri()->host()' );
        is( $creq->base->path, '/prefix/', 'X-Forwarded-Path => base()->path()' );
        is( $creq->uri->path, '/prefix/dump/request', 'X-Forwarded-Path => uri()->path()' );
        is( $creq->base->port, 12345, 'X-Forwarded-Port => base()->port()' );
        is( $creq->uri->port, 12345, 'X-Forwarded-Port => uri()->port()' );
        is( $creq->protocol, 'https', 'X-Forwarded-Is-Secure => protocol()' );
        ok( $creq->secure, 'X-Forwarded-Is-Secure => secure()' );
        is( $creq->base->scheme, 'https', 'X-Forwarded-Is-Secure => base()->scheme()' );
        is( $creq->uri->scheme, 'https', 'X-Forwarded-Is-Secure => uri()->scheme()' );
    }

    SKIP:
    {
        if ( $ENV{CATALYST_SERVER} ) {
            skip "Using remote server", 4;
        }
        # test that we can ignore the proxy support
        TestApp->config->{ignore_frontend_proxy} = 1;
        ok( $response = request($request), 'Request' );
        ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
        is( $creq->base, 'http://localhost/', 'Catalyst::Request non-proxied base' );
        is( $creq->address, '127.0.0.1', 'Catalyst::Request non-proxied address' );
    }
}
