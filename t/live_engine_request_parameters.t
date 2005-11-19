#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 28;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;
use URI;

{
    my $creq;

    my $parameters = { 'a' => [qw(A b C d E f G)], };

    my $query = join( '&', map { 'a=' . $_ } @{ $parameters->{a} } );

    ok( my $response = request("http://localhost/dump/request?$query"),
        'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like(
        $response->content,
        qr/^bless\( .* 'Catalyst::Request' \)$/s,
        'Content is a serialized Catalyst::Request'
    );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    isa_ok( $creq, 'Catalyst::Request' );
    is( $creq->method, 'GET', 'Catalyst::Request method' );
    is_deeply( $creq->{parameters}, $parameters,
        'Catalyst::Request parameters' );
}

{
    my $creq;

    my $parameters = {
        'a' => [qw(A b C d E f G)],
        '%' => [ '%', '"', '& - &' ],
    };

    my $request = POST(
        'http://localhost/dump/request/a/b?a=1&a=2&a=3',
        'Content'      => $parameters,
        'Content-Type' => 'application/x-www-form-urlencoded'
    );

    unshift( @{ $parameters->{a} }, 1, 2, 3 );

    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like(
        $response->content,
        qr/^bless\( .* 'Catalyst::Request' \)$/s,
        'Content is a serialized Catalyst::Request'
    );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    isa_ok( $creq, 'Catalyst::Request' );
    is( $creq->method, 'POST', 'Catalyst::Request method' );
    is_deeply( $creq->{parameters}, $parameters,
        'Catalyst::Request parameters' );
    is_deeply( $creq->arguments, [qw(a b)], 'Catalyst::Request arguments' );
    is_deeply( $creq->{uploads}, {}, 'Catalyst::Request uploads' );
    is_deeply( $creq->cookies,   {}, 'Catalyst::Request cookie' );
}

# http://dev.catalyst.perl.org/ticket/37
# multipart/form-data parameters that contain 'http://'
# was an HTTP::Message bug, but HTTP::Body handles it properly now
{
    my $creq;

    my $parameters = {
        'url' => 'http://www.google.com',
    };

    my $request = POST( 'http://localhost/dump/request',
        'Content-Type' => 'multipart/form-data',
        'Content'      => $parameters,
    );

    ok( my $response = request($request), 'Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is_deeply( $creq->{parameters}, $parameters, 'Catalyst::Request parameters' );
}

# raw query string support
{
    my $creq;
    
    my $parameters = {
        a => 1,
    };

    my $request = POST(
        'http://localhost/dump/request/a/b?query_string',
        'Content'      => $parameters,
        'Content-Type' => 'application/x-www-form-urlencoded'
    );
    
    ok( my $response = request($request), 'Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is( $creq->{uri}->query, 'query_string', 'Catalyst::Request POST query_string' );
    
    ok( $response = request('http://localhost/dump/request/a/b?x=1&y=1&z=1'), 'Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is( $creq->{uri}->query, 'x=1&y=1&z=1', 'Catalyst::Request GET query_string' );
}
