#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More tests => 2*$iters;
use Catalyst::Test 'TestAppPathBug';

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
            skip 'Using remote server', 2;
        }

        {
            my $expected = 'This is the foo method.';
            ok( my $response = request('http://localhost/'), 'response ok' );
            is( $response->content, $expected, 'Content OK' );
        }
    }
}
