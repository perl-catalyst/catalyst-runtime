#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 11;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;
use URI;

{
    my $creq;

    my $parameters = { 
        'a' => [qw(A b C d E f G)],
        '%' => [ '%', '"', '& - &' ],
    };

    my $request = POST( 'http://localhost/dump/request/a/b?a=1&a=2&a=3', 
        'Content'      => $parameters,
        'Content-Type' => 'application/x-www-form-urlencoded'
    );

    # Query string. I'm not sure the order is consistent in all enviroments,
    # we need to test this with:
    # [x] C::E::Test and C::E::Daemon
    # [ ] MP1
    # [ ] MP2
    # [x] CGI::Simple

    unshift( @{ $parameters->{a} }, 1, 2, 3 );
    
    ok( my $response = request($request), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    isa_ok( $creq, 'Catalyst::Request' );
    is( $creq->method, 'POST', 'Catalyst::Request method' );
    is_deeply( $creq->parameters, $parameters, 'Catalyst::Request parameters' );
    is_deeply( $creq->arguments, [qw(a b)], 'Catalyst::Request arguments' );
    is_deeply( $creq->uploads, {}, 'Catalyst::Request uploads' );
    is_deeply( $creq->cookies, {}, 'Catalyst::Request cookie' );
}
