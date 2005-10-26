#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../live/lib";

use Test::More;
use Catalyst::Test 'TestApp';
eval "use GTop2";

plan skip_all => 'set TEST_MEMLEAK to enable this test'
    unless $ENV{TEST_MEMLEAK};
plan skip_all => 'GTop required for this test' if $@;

plan tests => 1;

{
    # make a request to set initial memory size
    request('http://localhost');
    
    my $gtop = GTop->new;
    my $initial = $gtop->proc_mem($$)->size;
    print "Initial Size: $initial\n";
    
    for ( 1 .. 1000 ) {
        request('http://localhost');
    }
    
    my $final = $gtop->proc_mem($$)->size;
    print "Final Size:   $final\n";
    
    if ( $final > $initial ) {
        print "Leaked Bytes: " . ( $final - $initial ) . "\n";
    }
    
    is( $final, $initial, 'memory is not leaking' );
}
