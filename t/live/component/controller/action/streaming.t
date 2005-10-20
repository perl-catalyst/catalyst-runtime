#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 8;
use Catalyst::Test 'TestApp';

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
    
    ok( my $response = request('http://localhost/action/streaming/body'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content_type, 'text/plain', 'Response Content-Type' );
    is( $response->content, $buffer, 'Content is read from filehandle' );
}
