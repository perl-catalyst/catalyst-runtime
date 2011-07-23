package TestAppPathBug;
use Moose;
extends 'Catalyst';
use Catalyst;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppPathBug', root => '/some/dir' );

__PACKAGE__->log(TestAppPathBug::Log->new);
__PACKAGE__->setup;

package TestAppPathBug::Log;
use Moose;
extends 'Catalyst::Log';

sub warn {}

1;
