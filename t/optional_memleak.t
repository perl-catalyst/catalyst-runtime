#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Catalyst::Test 'TestApp';
use YAML;
eval "use Proc::ProcessTable";

plan skip_all => 'set TEST_MEMLEAK to enable this test'
    unless $ENV{TEST_MEMLEAK};
plan skip_all => 'Proc::ProcessTable required for this test' if $@;

eval "use HTTP::Body 0.03";
plan skip_all => 'HTTP::Body >= 0.03 required for this test' if $@;

our $t = Proc::ProcessTable->new( cache_ttys => 1 );
our ( $initial, $final ) = ( 0, 0 ); 
our $tests = YAML::LoadFile("$FindBin::Bin/optional_stress.yml");

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
        print "Leaked:       " . ($final - $initial) . "\n";
    }
    
    is( $final, $initial, "'$uri' memory is not leaking" );
}

sub size_of {
    my $pid = shift;
    
    foreach my $p ( @{ $t->table } ) {
        if ( $p->pid == $pid ) {
            return $p->size;
        }
    }
    
    die "Pid $pid not found?";
}

