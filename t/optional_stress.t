use strict;
use warnings;

use Test::More;
BEGIN {
    plan skip_all => 'set TEST_STRESS to enable this test'
      unless $ENV{TEST_STRESS};
}

use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp';

our ( $iters, $tests );

BEGIN {
    use JSON::MaybeXS qw(decode_json);

    my $test_data = do {
      open my $fh, '<:raw', "$FindBin::Bin/optional_stress.json" or die "$!";
      local $/;
      <$fh>;
    };

    $iters = $ENV{TEST_STRESS} || 10;
    $tests = decode_json($test_data);

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
