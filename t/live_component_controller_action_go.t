#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More tests => 47 * $iters;
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
        my @expected = qw[
          TestApp::Controller::Action::Go->one
          TestApp::Controller::Action::Go->two
          TestApp::Controller::Action::Go->three
          TestApp::Controller::Action::Go->four
          TestApp::Controller::Action::Go->five
          TestApp::View::Dump::Request->process
          TestApp->end
        ];

        @expected = map { /Action/ ? (_begin($_), $_) : ($_) } @expected;
        my $expected = join( ", ", @expected );

        # Test go to global private action
        ok( my $response = request('http://localhost/action/go/global'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action/go/global', 'Main Class Action' );

        # Test go to chain of actions.
        ok( $response = request('http://localhost/action/go/one'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action/go/one', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Go',
            'Test Class'
        );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    {
        my @expected = qw[
          TestApp::Controller::Action::Go->go_die
          TestApp::Controller::Action::Go->args
          TestApp->end
        ];

        @expected = map { /Action/ ? (_begin($_), $_) : ($_) } @expected;
        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/action/go/go_die'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action/go/go_die', 'Test Action'
        );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Go',
            'Test Class'
        );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, $Catalyst::GO, "Go died as expected" );
    }

    {
        ok(
            my $response =
              request('http://localhost/action/go/with_args/old'),
            'Request with args'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content, 'old' );
    }

    {
        ok(
            my $response = request(
                'http://localhost/action/go/with_method_and_args/new'),
            'Request with args and method'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content, 'new' );
    }

    # test go with embedded args
    {
        ok(
            my $response =
              request('http://localhost/action/go/args_embed_relative'),
            'Request'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content, 'ok' );
    }

    {
        ok(
            my $response =
              request('http://localhost/action/go/args_embed_absolute'),
            'Request'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content, 'ok' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::TestRelative->relative_go
          TestApp::Controller::Action::Go->one
          TestApp::Controller::Action::Go->two
          TestApp::Controller::Action::Go->three
          TestApp::Controller::Action::Go->four
          TestApp::Controller::Action::Go->five
          TestApp::View::Dump::Request->process
          TestApp->end
        ];

        @expected = map { /Action/ ? (_begin($_), $_) : ($_) } @expected;
        my $expected = join( ", ", @expected );

        # Test go to chain of actions.
        ok( my $response = request('http://localhost/action/relative/relative_go'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'),
            'action/relative/relative_go', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Go',
            'Test Class'
        );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::TestRelative->relative_go_two
          TestApp::Controller::Action::Go->one
          TestApp::Controller::Action::Go->two
          TestApp::Controller::Action::Go->three
          TestApp::Controller::Action::Go->four
          TestApp::Controller::Action::Go->five
          TestApp::View::Dump::Request->process
          TestApp->end
        ];

        @expected = map { /Action/ ? (_begin($_), $_) : ($_) } @expected;
        my $expected = join( ", ", @expected );

        # Test go to chain of actions.
        ok(
            my $response =
              request('http://localhost/action/relative/relative_go_two'),
            'Request'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is(
            $response->header('X-Catalyst-Action'),
            'action/relative/relative_go_two',
            'Test Action'
        );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Go',
            'Test Class'
        );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );
    }

    # test class go 
    {
        ok(
            my $response = request(
                'http://localhost/action/go/class_go_test_action'),
            'Request'
        );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->header('X-Class-Go-Test-Method'), 1,
            'Test Method' );
    }

}

sub _begin {
    local $_ = shift;
    s/->(.*)$/->begin/;
    return $_;
}

