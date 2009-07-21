use strict;
use warnings;
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, q(lib) );

use English qw( -no_match_vars );
use Test::More tests => 10;
use URI;

use_ok( q(TestApp) );

my $request = Catalyst::Request->new( {
   base => URI->new( q(http://127.0.0.1) ) } );

my $context = TestApp->new( { request => $request, namespace => '', } );

# Well if it's not a plugin... where to put the config options?
my $KEY = q(Plugin::ContextualUriFor);

# If the first arg is false does we do a default action OR pass to core uri_for
# I think this required as it is an either or case
$context->config->{ $KEY }->{defaults_to_action} = 1;

# I want the option to either die or log at a given level and return undef
# This is fluff, should probably just do what core uri_for does on error
$context->config->{ $KEY }->{on_error} = q(die);

# The default method name is "default" but I want to override
# Really need this one
$context->config->{ $KEY }->{default_action} = q(chain_root_index);

# This still has to work even if "defaults_to_action" is true
is( $context->uri_for->as_string,
    q(http://127.0.0.1/),
    'URI for default action' );

# This still has to work even if "defaults_to_action" is true
is( $context->uri_for( q(), q(en) )->as_string,
    q(http://127.0.0.1/en),
    'URI for default action plus arg' );

is( $context->uri_for( q(root/test), qw(en a) ),
    q(http://127.0.0.1/en/base/a/test),
    'URI for test action' );

is( $context->uri_for( q(root/test), qw(en a b) ),
    q(http://127.0.0.1/en/base/a/test/b),
    'URI for test action with some args' );

is( $context->uri_for( q(root/test), qw(en a b), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/base/a/test/b?key1=value1),
    'URI for test action with some args and params' );

is( $context->uri_for( qw(Root test), qw(en a b), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/base/a/test/b?key1=value1),
    'URI for controller and method' );

is( $context->uri_for( qw(Root), undef, qw(en a b), { key1 => q(value1) } ),
    q(http://127.0.0.1/en/a/b?key1=value1),
    'URI for controller and default method' );

eval { $context->uri_for( q(root/base), q(en) ) };

like( $EVAL_ERROR,
      qr(\A Action \s base \s is \s a \s midpoint)msx,
      'Midpoint detected' );

eval { $context->uri_for( q(root/test), q(en) ) };

like( $EVAL_ERROR,
      qr(\A Action \s test \s insufficient \s args)msx,
      'Insufficient args' );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
