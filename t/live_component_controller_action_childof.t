#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 9*$iters;
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
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo
          TestApp::Controller::Action::ChildOf->endpoint
          TestApp::Controller::Action::ChildOf->end
        ];
    
        my $expected = join( ", ", @expected );
    
        ok( my $response = request('http://localhost/childof/foo/1/end/2'), 'childof + local endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo
          TestApp::Controller::Action::ChildOf::Foo->spoon
          TestApp::Controller::Action::ChildOf->end
        ];
    
        my $expected = join( ", ", @expected );
    
        ok( my $response = request('http://localhost/childof/foo/1/spoon'), 'childof + subcontroller endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; ', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->bar
          TestApp::Controller::Action::ChildOf->finale
          TestApp::Controller::Action::ChildOf->end
        ];
    
        my $expected = join( ", ", @expected );
    
        ok( my $response = request('http://localhost/childof/bar/1/spoon'), 'childof + relative endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 1, spoon', 'Content OK' );
    }
}
