#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 20;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;

{
    my $creq;

    my $request = POST( 'http://localhost/dump/request/',
        'Content-Type' => 'text/plain',
        'Content'      => 'Hello Catalyst'
    );

    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
    
    {
        no strict 'refs';
        ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    }

    isa_ok( $creq, 'Catalyst::Request' );
    is( $creq->method, 'POST', 'Catalyst::Request method' );
    is( $creq->content_type, 'text/plain', 'Catalyst::Request Content-Type' );
    is( $creq->content_length, $request->content_length, 'Catalyst::Request Content-Length' );
    is( $creq->body, $request->content, 'Catalyst::Request Content' );
}

{
    my $creq;

    my $request = POST( 'http://localhost/dump/request/',
        'Content-Type' => 'text/plain',
        'Content'      => 'x' x 100_000
    );

    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
    
    {
        no strict 'refs';
        ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    }

    isa_ok( $creq, 'Catalyst::Request' );
    is( $creq->method, 'POST', 'Catalyst::Request method' );
    is( $creq->content_type, 'text/plain', 'Catalyst::Request Content-Type' );
    is( $creq->content_length, $request->content_length, 'Catalyst::Request Content-Length' );
    is( $creq->body, $request->content, 'Catalyst::Request Content' );
}