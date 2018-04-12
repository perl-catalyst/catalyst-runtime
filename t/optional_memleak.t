use strict;
use warnings;

use Test::More;
BEGIN {
    plan skip_all => 'set TEST_MEMLEAK to enable this test'
        unless $ENV{TEST_MEMLEAK};
}

use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp';

eval "use Proc::ProcessTable";
plan skip_all => 'Proc::ProcessTable required for this test' if $@;

use JSON::MaybeXS qw(decode_json);

our $t = Proc::ProcessTable->new( cache_ttys => 1 );
our ( $initial, $final ) = ( 0, 0 ); 
my $test_data = do {
  open my $fh, '<:raw', "$FindBin::Bin/optional_stress.json" or die "$!";
  local $/;
  <$fh>;
};

our $tests = decode_json($test_data);

my $total_tests = 0;

# let the user specify a single uri to test
my $user_test = shift;
if ( $user_test ) {
    plan tests => 1;
    run_test( $user_test );
}
# otherwise, run all tests
else {
    map { $total_tests += scalar @{ $tests->{$_} } } keys %{$tests};
    plan tests => $total_tests;
    
    foreach my $test_group ( keys %{$tests} ) {
        foreach my $test ( @{ $tests->{$test_group} } ) {
            run_test( $test );
        }
    }
}

sub run_test {
    my $uri = shift || die 'No URI given for test';
    
    print "TESTING $uri\n";
    
    # make a few requests to set initial memory size
    for ( 1 .. 3 ) {
        request( $uri );
    }
    
    $initial = size_of($$);
    print "Initial Size: $initial\n";
    
    for ( 1 .. 500 ) {
        request( $uri );
    }
    
    $final = size_of($$);
    print "Final Size:   $final\n";
    
    if ( $final > $initial ) {
        print "Leaked:       " . ($final - $initial) . "K\n";
    }
    
    is( $final, $initial, "'$uri' memory is not leaking" );
}

sub size_of {
    my $pid = shift;
    
    foreach my $p ( @{ $t->table } ) {
        if ( $p->pid == $pid ) {
            return $p->rss;
        }
    }
    
    die "Pid $pid not found?";
}

