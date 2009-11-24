use strict;
use warnings;

package TestAppPathBug;
use strict;
use warnings;
use Catalyst;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'TestAppPathBug', root => '/some/dir' );

__PACKAGE__->log(TestAppPathBug::Log->new);
__PACKAGE__->setup;

sub foo : Path {
    my ( $self, $c ) = @_;
    $c->res->body( 'This is the foo method.' );
}

package TestAppPathBug::Log;
use strict;
use warnings;
use base qw/Catalyst::Log/;

sub warn {}

1;
