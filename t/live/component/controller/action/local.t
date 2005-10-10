#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 24;
use Catalyst::Test 'TestApp';


{
    ok( my $response = request('http://localhost/action/local/one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/local/one', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Local', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action/local/two'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/local/two', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Local', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action/local/three'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/local/three', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Local', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action/local/four/five/six'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/local/four/five/six', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Local', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
