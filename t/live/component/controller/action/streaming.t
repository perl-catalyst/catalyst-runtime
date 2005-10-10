#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 4;
use Catalyst::Test 'TestApp';

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
