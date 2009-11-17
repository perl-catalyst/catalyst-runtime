use strict;
use warnings;

package TestAppSimple;

use Catalyst qw/
    Test::MangleDollarUnderScore
    Test::Errors 
    Test::Headers 
    Test::Plugin
/;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppStats', root => '/some/dir' );

__PACKAGE__->setup;

1;


