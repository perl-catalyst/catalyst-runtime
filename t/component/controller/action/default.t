#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests=>9 ;
use Catalyst::Test 'TestApp';


{
    my @expected = qw[
        TestApp::Controller::Action::Default->begin
        TestApp::Controller::Action::Default->default
        TestApp::View::Dump::Request->process
    ];

    my $expected = join( ", ", @expected );

    ok( my $response = request('http://localhost/action/default'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'default', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Default', 'Test Class' );
    is( $response->header('X-Catalyst-Executed'), $expected, 'Executed actions' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );

    ok( $response = request('http://localhost/foo/bar/action'), 'Request' );
    is( $response->code, 404, 'Invalid URI returned 404' );
}
