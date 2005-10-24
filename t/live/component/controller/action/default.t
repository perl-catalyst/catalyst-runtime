#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 12*$iters;
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
          TestApp::Controller::Action::Default->begin
          TestApp::Controller::Action::Default->default
          TestApp::View::Dump::Request->process
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/action/default'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->header('X-Catalyst-Action'), 'default', 'Test Action' );
        is(
            $response->header('X-Test-Class'),
            'TestApp::Controller::Action::Default',
            'Test Class'
        );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        like(
            $response->content,
            qr/^bless\( .* 'Catalyst::Request' \)$/s,
            'Content is a serialized Catalyst::Request'
        );

        ok( $response = request('http://localhost/foo/bar/action'), 'Request' );
        is( $response->code, 404, 'Invalid URI returned 404' );
    }
    
    # test that args are passed properly to default
    {
        my $creq;
        my $expected = [ qw/action default arg1 arg2/ ];
        
        ok( my $response = request('http://localhost/action/default/arg1/arg2'), 'Request' );
        ok( eval '$creq = ' . $response->content, 'Unserialize Catalyst::Request' );
        is_deeply( $creq->{arguments}, $expected, 'Arguments ok' );
    }
}
