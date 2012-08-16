#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 8;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;

{
    my $creq;

    my $parameters = { 'a' => [qw(A b C d E f G)], };

    my $query = join( '&', map { 'a=' . $_ } @{ $parameters->{a} } );

    ok( my $response = request("http://localhost/dump/prepare_parameters?$query"),
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
    is_deeply( $creq->parameters, $parameters,
        'Catalyst::Request parameters' );
}


