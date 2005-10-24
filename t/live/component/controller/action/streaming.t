#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 8*$iters;
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
    # test direct streaming
    {
        ok( my $response = request('http://localhost/streaming'), 'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->content,, <<'EOF', 'Content is a stream' );
foo
bar
baz
EOF
    }

    # test streaming by passing a handle to $c->res->body
  SKIP:
    {
        if ( $ENV{CATALYST_SERVER} ) {
            skip "Using remote server", 4;
        }

        my $file = "$FindBin::Bin/../../../../01use.t";
        my $fh = IO::File->new( $file, 'r' );
        my $buffer;
        if ( defined $fh ) {
            $fh->read( $buffer, 1024 );
            $fh->close;
        }

        ok( my $response = request('http://localhost/action/streaming/body'),
            'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->content, $buffer, 'Content is read from filehandle' );
    }
}
