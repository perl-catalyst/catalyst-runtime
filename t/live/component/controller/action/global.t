#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 18;
use Catalyst::Test 'TestApp';


{
    ok( my $response = request('http://localhost/action_global_one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_global_one', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Global', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action_global_two'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_global_two', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Global', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action_global_three'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_global_three', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Global', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
