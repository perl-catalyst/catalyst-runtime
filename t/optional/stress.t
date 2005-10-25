#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../live/lib";

use Test::More;
use Catalyst::Test 'TestApp';
use YAML;

our ( $iters, $tests );

BEGIN {
    plan skip_all => 'set TEST_STRESS to enable this test'
      unless $ENV{TEST_STRESS};

    $iters = $ENV{TEST_STRESS} || 10;
    $tests = YAML::LoadFile("$FindBin::Bin/stress.yml");

    my $total_tests = 0;
    map { $total_tests += scalar @{ $tests->{$_} } } keys %{$tests};
    plan tests => $iters * $total_tests;
}

for ( 1 .. $iters ) {
    run_tests();
}

sub run_tests {
    foreach my $test_group ( keys %{$tests} ) {
        foreach my $test ( @{ $tests->{$test_group} } ) {
            ok( request($test), $test_group . ' - ' . $test );
        }
    }
}
