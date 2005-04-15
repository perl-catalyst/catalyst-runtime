#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 12;
use Catalyst::Test 'TestApp';


{
    ok( my $response = request('http://localhost/action/regexp/10/hello'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), '^action/regexp/(\d+)/(\w+)$', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Regexp', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    ok( my $response = request('http://localhost/action/regexp/hello/10'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), '^action/regexp/(\w+)/(\d+)$', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Regexp', 'Test Class' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
