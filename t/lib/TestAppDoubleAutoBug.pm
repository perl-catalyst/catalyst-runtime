use strict;
use warnings;

package TestAppDoubleAutoBug;

use Catalyst qw/
    Test::Errors
    Test::Headers
    Test::Plugin
/;

use TestApp::Context;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppDoubleAutoBug', root => '/some/dir' );
__PACKAGE__->context_class( 'TestApp::Context' );
__PACKAGE__->setup;

1;

