use strict;
use warnings;

package TestAppPathBug;

use Catalyst;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppPathBug', root => '/some/dir' );

__PACKAGE__->setup;

1;
