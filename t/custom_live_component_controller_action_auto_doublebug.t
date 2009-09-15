#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More tests => 3*$iters;
use Catalyst::Test 'TestAppDoubleAutoBug';

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
    SKIP:
    {
        if ( $ENV{CATALYST_SERVER} ) {
            skip 'Using remote server', 3;
        }
        
        {
            my @expected = qw[
                TestAppDoubleAutoBug::Controller::Root->auto
                TestAppDoubleAutoBug::Controller::Root->default
                TestAppDoubleAutoBug::Controller::Root->end
            ];
    
            my $expected = join( ", ", @expected );
    
            ok( my $response = request('http://localhost/action/auto/one'), 'auto + local' );
            is( $response->header('X-Catalyst-Executed'),
                $expected, 'Executed actions' );
            is( $response->content, 'default, auto=1', 'Content OK' );
        }
    }
}
