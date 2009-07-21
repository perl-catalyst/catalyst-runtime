use strict;
use warnings;
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, q(lib) );

use English qw( -no_match_vars );
use Test::More tests => 11;
use URI;

use_ok( q(TestApp) );

my $request = Catalyst::Request->new( {
   base => URI->new( q(http://127.0.0.1) ) } );

my $context = TestApp->new( {
   config    => { uri_for_defaults_to_action => 1,
                  uri_for_default_action     => q(chain_root_index),
                  uri_for_on_error           => q(die) },
   request   => $request,
   namespace => q(), } );

is( $context->uri_for,
    q(http://127.0.0.1/),
    'URI for default action' );

is( $context->uri_for( qw(root/just_one_arg a) ),
    q(http://127.0.0.1/just_one_arg/a),
    'URI for action with just one arg and no captures' );

is( $context->uri_for( q(), q(en) ),
    q(http://127.0.0.1/en),
    'URI for default action plus leading capture arg' );

is( $context->uri_for( qw(root/slurpy_endpoint en a) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint),
    'URI for slurpy_endpoint no args or params' );

is( $context->uri_for( qw(root/slurpy_endpoint en a b c) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c),
    'URI for slurpy_endpoint with some args' );

is( $context->uri_for( qw(root/slurpy_endpoint en a b c), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c?key1=value1),
    'URI for slurpy_endpoint with some args and params' );

is( $context->uri_for( qw(Root slurpy_endpoint en a b c) ),
    q(http://127.0.0.1/en/midpoint_capture/a/slurpy_endpoint/b/c),
    'URI for controller and method' );

is( $context->uri_for( q(Root), undef, qw(en a b c), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/a/b/c?key1=value1),
    'URI for controller and default method' );

eval { $context->uri_for( qw(root/midpoint_capture en) ) };

like( $EVAL_ERROR,
      qr(\A Action \s midpoint_capture \s is \s a \s midpoint)msx,
      'Midpoint detected' );

eval { $context->uri_for( qw(root/slurpy_endpoint en) ) };

like( $EVAL_ERROR,
      qr(\A Action \s slurpy_endpoint \s insufficient \s args)msx,
      'Insufficient args' );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
