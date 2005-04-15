#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests=>7;
use Catalyst::Test 'TestApp';


{
    my @expected = qw[
        TestApp::Controller::Action::Begin->begin
        TestApp::Controller::Action::Begin->default
        TestApp::View::Dump::Request->process
    ];

    my $expected = join( ", ", @expected );

    ok( my $response = request('http://localhost/action/begin'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'default', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Begin', 'Test Class' );
    is( $response->header('X-Catalyst-Executed'), $expected, 'Executed actions' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
