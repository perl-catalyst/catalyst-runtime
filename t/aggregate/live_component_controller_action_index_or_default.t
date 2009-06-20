#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More tests => 3*$iters;

use Catalyst::Test 'TestAppIndexDefault';

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
    is(get('/indexchained'), 'index_chained', ':Chained overrides index');
    is(get('/indexprivate'), 'index_private', 'index : Private still works');
    is(get('/one_arg'), 'path_one_arg', ':Path overrides default');
}
