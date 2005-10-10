#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 24;
use Catalyst::Test 'TestApp';


{
    ok( my $response = request('http://localhost/action/private/one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Private', 'Test Class' );
    is( $response->content, 'access denied', 'Access' );
}

{
    ok( my $response = request('http://localhost/action/private/two'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Private', 'Test Class' );
    is( $response->content, 'access denied', 'Access' );
}

{
    ok( my $response = request('http://localhost/three'), 'Request' );
    ok( $response->is_error, 'Response Server Error 5xx' );
    is( $response->content_type, 'text/html', 'Response Content-Type' );
    like( $response->header('X-Catalyst-Error'), qr/^Unknown resource "three"/, 'Catalyst Error' );
}

{
    ok( my $response = request('http://localhost/action/private/four'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Private', 'Test Class' );
    is( $response->content, 'access denied', 'Access' );
}

{
    ok( my $response = request('http://localhost/action/private/five'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Private', 'Test Class' );
    is( $response->content, 'access denied', 'Access' );
}
