use strict;
use warnings;
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) ), catdir( $Bin, q(lib) );

use English qw( -no_match_vars );
use Test::More tests => 26;
use URI;

{   package TestApp;

    use Catalyst;

    __PACKAGE__->config
       ( contextual_uri_for        => 1,
         dispatcher_default_action => q(default_endpoint), );

    __PACKAGE__->setup;

    1;
}

my $request = Catalyst::Request->new( {
    base => URI->new( q(http://127.0.0.1) ) } );

my $context = TestApp->new( { request => $request } );

is( $context->uri_for,
    q(http://127.0.0.1/),
    'URI for default private path with no args at all' );

is( $context->uri_for( q(), q(en) ),
    q(http://127.0.0.1/en),
    'URI for default private path plus leading capture arg' );

is( $context->uri_for( qw(root) ),
    q(http://127.0.0.1/),
    'URI for private path with default action name and no args at all' );

is( $context->uri_for( qw(/just_one_arg a) ),
    q(http://127.0.0.1/just_one_arg/a),
    'URI for private path with default namespace' );

is( $context->uri_for( qw(root/just_one_arg a) ),
    q(http://127.0.0.1/just_one_arg/a),
    'URI for private path with just one arg and no captures' );

is( $context->uri_for( qw(root/slurpy_endpoint en a) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint),
    'URI for slurpy_endpoint no args or params' );

is( $context->uri_for( qw(root/slurpy_endpoint en a b c) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c),
    'URI for slurpy_endpoint with some args' );

is( $context->uri_for( qw(root/slurpy_endpoint en a b c), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c?key1=value1),
    'URI for slurpy_endpoint with some args and params' );

is( $context->uri_for( qw(Chained::ContextualUriFor slurpy_endpoint en a b c) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c),
    'URI for controller and method' );

is( $context->uri_for( q(Chained::ContextualUriFor) ),
    q(http://127.0.0.1/),
    'URI for controller and default method' );

# Existing tests

$request = Catalyst::Request->new( {
    base => URI->new( q(http://127.0.0.1/foo) ) } );

$context = TestApp->new( { namespace => q(yada), request => $request } );

is( $context->uri_for( '/bar/baz' ),
    'http://127.0.0.1/foo/bar/baz',
    'URI for absolute path' );

is( $context->uri_for( 'bar/baz' ),
    'http://127.0.0.1/foo/yada/bar/baz',
    'URI for relative path' );

# Not compatable with default private path
#is( $context->uri_for( '', 'arg1', 'arg2' ),
#    'http://127.0.0.1/foo/yada/arg1/arg2',
#    'URI for undef action with args' );

is( $context->uri_for( '../quux' ),
    'http://127.0.0.1/foo/quux',
    'URI for relative dot path' );

is( $context->uri_for( 'quux', { param1 => 'value1' } ),
    'http://127.0.0.1/foo/yada/quux?param1=value1',
    'URI for undef action with query params' );

is( $context->uri_for( '/bar/wibble?' ),
    'http://127.0.0.1/foo/bar/wibble%3F',
    'Question Mark gets encoded' );

is( $context->uri_for( qw/bar wibble?/, 'with space' ),
    'http://127.0.0.1/foo/yada/bar/wibble%3F/with%20space',
    'Space gets encoded' );

is( $context->uri_for( '/bar', 'with+plus', { 'also' => 'with+plus' } ),
    'http://127.0.0.1/foo/bar/with+plus?also=with%2Bplus',
    'Plus is not encoded' );

is( $context->uri_for( 'quux', { param1 => "\x{2620}" } ),
    'http://127.0.0.1/foo/yada/quux?param1=%E2%98%A0',
    'URI for undef action with query params in unicode' );

is( $context->uri_for( 'quux', { 'param:1' => "foo" } ),
    'http://127.0.0.1/foo/yada/quux?param%3A1=foo',
    'URI for undef action with query params in unicode' );

is( $context->uri_for( 'quux', { param1 => $request->base } ),
    'http://127.0.0.1/foo/yada/quux?param1=http%3A%2F%2F127.0.0.1%2Ffoo',
    'URI for undef action with query param as object' );

$request->base( URI->new( 'http://localhost:3000/' ) );
$request->match( 'orderentry/contract' );

is( $context->uri_for( '/Orderentry/saveContract' ),
    'http://localhost:3000/Orderentry/saveContract',
    'URI for absolute path' );

$request->base( URI->new( 'http://127.0.0.1/' ) );
$context->namespace( q() );

is( $context->uri_for( '/bar/baz' ),
    'http://127.0.0.1/bar/baz',
    'URI with no base or match' );

is( $context->uri_for( qw/0 foo/ ),
    'http://127.0.0.1/0/foo',
    '0 as path is ok' );

{   my $warnings = 0;
    local $SIG{__WARN__} = sub { $warnings++ };

    $context->uri_for( '/bar/baz', { foo => undef } ),
    is( $warnings, 0, "no warnings emitted" );
}

is( $context->uri_for( qw| / foo bar | ),
    'http://127.0.0.1/foo/bar',
    'uri is /foo/bar, not //foo/bar' );

my $query_params_base = { test => "one two",
                          bar  => [ "foo baz", "bar" ] };
my $query_params_test = { test => "one two",
                          bar  => [ "foo baz", "bar" ] };

$context->uri_for( '/bar/baz', $query_params_test );
is_deeply( $query_params_base,
           $query_params_test,
           "uri_for() doesn't mess up query parameter hash in the caller" );

# Local Variables:
# mode: perl
# tab-width: 4
# End:
