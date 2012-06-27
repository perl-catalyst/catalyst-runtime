#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More;
use Catalyst::Test 'TestApp';

if ( $ENV{CAT_BENCHMARK} ) {
    require Benchmark;
    Benchmark::timethis( $iters, \&run_tests );
}
else {
    for ( 1 .. $iters ) {
        run_tests();
    }
}

sub run_tests {
    {
        ok( my $response = request('http://localhost/action_action_one'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_one', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-Action'), 'works' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_two'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_two', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-Action-After'), 'awesome' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok(
            my $response =
              request('http://localhost/action_action_three/one/two'),
            'Request'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_three', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-TestAppActionTestBefore'), 'one' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_four'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_four', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-TestAppActionTestMyAction'), 'MyAction works' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_five'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_five', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-Action'), 'works' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_six'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_six', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-TestAppActionTestMyAction'), 'MyAction works' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_seven'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_seven', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-TestExtraArgsAction'), '42,23', 'Extra args get passed to action contstructor' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        ok( my $response = request('http://localhost/action_action_eight'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_eight', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Action' \)$/s,
            'Content is a serialized Catalyst::Action'
        );

        require Catalyst::Action; # when running against a remote server, we
                                  # need to load the class in the test process
                                  # to be able to introspect the action instance
                                  # later.
        my $action = eval $response->content;
        is_deeply $action->attributes->{extra_attribute}, [13];
        is_deeply $action->attributes->{another_extra_attribute}, ['foo'];
    }
    {
        ok( my $response = request('http://localhost/action_action_nine'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action_action_nine', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Action',
            'Test Class'
        );
        is( $response->header('X-TestExtraArgsAction'), '42,13', 'Extra args get passed to action constructor' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }
}

done_testing;
