use strict;
use warnings;
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) ), catdir( $Bin, q(lib) );

use English qw( -no_match_vars );
use Test::More tests => 11;
use URI;

use_ok( q(TestApp) );

my $request = Catalyst::Request->new( {
    base => URI->new( q(http://127.0.0.1) ) } );

my $context = TestApp->new( { request => $request } );

$context->config( contextual_uri_for        => 1,
                  dispatcher_default_action => q(default_endpoint), );

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

# Local Variables:
# mode: perl
# tab-width: 4
# End:
