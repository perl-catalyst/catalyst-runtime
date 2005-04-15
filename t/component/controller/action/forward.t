#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 18;
use Catalyst::Test 'TestApp';


{
    my @expected = qw[
        TestApp::Controller::Action::Forward->begin
        TestApp::Controller::Action::Forward->one
        TestApp::Controller::Action::Forward->two
        TestApp::Controller::Action::Forward->three
        TestApp::Controller::Action::Forward->four
        TestApp::Controller::Action::Forward->five
        TestApp::View::Dump::Request->process
    ];

    my $expected = join( ", ", @expected );

   # Test forward to global private action
    ok( my $response = request('http://localhost/action/forward/global'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/forward/global', 'Main Class Action' );
    # Test forward to chain of actions.
    ok( $response = request('http://localhost/action/forward/one'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/forward/one', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Forward', 'Test Class' );
    is( $response->header('X-Catalyst-Executed'), $expected, 'Executed actions' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}

{
    my @expected = qw[
        TestApp::Controller::Action::Forward->begin
        TestApp::Controller::Action::Forward->jojo
        TestApp::Controller::Action::Forward->one
        TestApp::Controller::Action::Forward->two
        TestApp::Controller::Action::Forward->three
        TestApp::Controller::Action::Forward->four
        TestApp::Controller::Action::Forward->five
        TestApp::View::Dump::Request->process
        TestApp::Controller::Action::Forward->three
        TestApp::Controller::Action::Forward->four
        TestApp::Controller::Action::Forward->five
        TestApp::View::Dump::Request->process
    ];

    my $expected = join( ", ", @expected );

    ok( my $response = request('http://localhost/action/forward/jojo'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->header('X-Catalyst-Action'), 'action/forward/jojo', 'Test Action' );
    is( $response->header('X-Test-Class'), 'TestApp::Controller::Action::Forward', 'Test Class' );
    is( $response->header('X-Catalyst-Executed'), $expected, 'Executed actions' );
    like( $response->content, qr/^bless\( .* 'Catalyst::Request' \)$/s, 'Content is a serialized Catalyst::Request' );
}
