use strict;
use warnings;

package TestAppDoubleAutoBug;

use Catalyst qw/
    Test::Errors
    Test::Headers
    Test::Plugin
/;

use TestAppDoubleAutoBug::Context;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppDoubleAutoBug', root => '/some/dir' );
__PACKAGE__->context_class( 'TestAppDoubleAutoBug::Context' );
__PACKAGE__->setup;

1;

