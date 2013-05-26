package ACLTestApp;
use Test::More;

use strict;
use warnings;
use MRO::Compat;
use Scalar::Util ();
use TestLogger;

use base qw/Catalyst Catalyst::Controller/;
use Catalyst qw//;

__PACKAGE__->log(TestLogger->new);

sub execute {
    my $c = shift;
    my ( $class, $action ) = @_;

    if ( Scalar::Util::blessed($action)
	 and $action->name ne "foobar" ) {
	eval { $c->detach( 'foobar', [$action, 'foo'] ) };
    }

    $c->next::method( @_ );
}

__PACKAGE__->setup;

1;
