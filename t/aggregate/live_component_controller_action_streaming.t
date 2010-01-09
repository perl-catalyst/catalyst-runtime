#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 1; }

use Test::More;
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

        SKIP:
        {
            if ( $ENV{CATALYST_SERVER} ) {
                skip "Using remote server", 1;
            }

            ok(!defined $response->content_length, 'No Content-Length for streaming responses');
            is(length $response->content, 12, 'Response content' );
        }

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
            skip "Using remote server", 5;
        }

        my $file = "$FindBin::Bin/../lib/TestApp/Controller/Action/Streaming.pm";
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
        is( $response->content_length, -s $file, 'Response Content-Length' );
        is( $response->content, $buffer, 'Content is read from filehandle' );
    }

    {
        my $size = 128 * 1024; # more than one read with the default chunksize

        ok( my $response = request('http://localhost/action/streaming/body_large'), 'Request' );
        ok( $response->is_success, 'Response Successful 2xx' );
        is( $response->content_type, 'text/plain', 'Response Content-Type' );
        is( $response->content_length, $size, 'Response Content-Length' );
        is( $response->content, "\0" x $size, 'Content is read from filehandle' );
    }
}

done_testing;
