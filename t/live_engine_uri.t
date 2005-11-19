#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 23;
use Catalyst::Test 'TestApp';
use Catalyst::Request;

my $creq;

# test that the path can be changed
{
    ok( my $response = request('http://localhost/engine/request/uri/change_path'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    like( $creq->uri, qr{/my/app/lives/here$}, 'URI contains new path' );
}

# test that path properly removes the base location
{
    ok( my $response = request('http://localhost/engine/request/uri/change_base'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    like( $creq->base, qr{/new/location}, 'Base URI contains new location' );
    is( $creq->path, 'engine/request/uri/change_base', 'URI contains correct path' );
}

# test that base + path is correct
{
    ok( my $response = request('http://localhost/engine/request/uri'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is( $creq->base . $creq->path, $creq->uri, 'Base + Path ok' );
}

# test that we can use semi-colons as separators
{
    my $parameters = {
        a => [ qw/1 2/ ],
        b => 3,
    };
    
    ok( my $response = request('http://localhost/engine/request/uri?a=1;a=2;b=3'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is( $creq->{uri}->query, 'a=1;a=2;b=3', 'Query string ok' );
    is_deeply( $creq->{parameters}, $parameters, 'Parameters ok' );
}

# test that query params are unescaped properly
{
    ok( my $response = request('http://localhost/engine/request/uri?text=Catalyst%20Rocks'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
    is( $creq->{uri}->query, 'text=Catalyst%20Rocks', 'Query string ok' );
    is( $creq->{parameters}->{text}, 'Catalyst Rocks', 'Unescaped param ok' );
}
