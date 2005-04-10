#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More no_plan => 1;
use Catalyst::Test 'TestApp';


{
    ok( my $response = request('http://localhost/action_absolute_one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_absolute_one', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Absoulte', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action_absolute_two'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_absolute_two', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Absoulte', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action_absolute_three'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action_absolute_three', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Absoulte', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
