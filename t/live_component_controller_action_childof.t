#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 27*$iters;
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
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo2
          TestApp::Controller::Action::ChildOf->endpoint2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/foo2/10/20/end2/15/25'), 
            'childof + local (2 args each)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '10, 20; 15, 25', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23'),
            'three-chain (only first)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one
          TestApp::Controller::Action::ChildOf->two_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23/two/23/46'),
            'three-chain (up to second)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '23; 23, 46', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one
          TestApp::Controller::Action::ChildOf->two
          TestApp::Controller::Action::ChildOf->three_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23/two/23/46/three/1/2/3'),
            'three-chain (all three)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '23, 23, 46; 1, 2, 3', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi1
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi/23'),
            'multi-action (one arg)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23', 'Content OK' );
    }
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi/23/46'),
            'multi-action (two args)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23, 46', 'Content OK' );
    }
}
