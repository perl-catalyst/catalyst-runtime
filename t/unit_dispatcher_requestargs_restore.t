# Insane test case for the behavior needed by Plugin::Auhorization::ACL

# We have to localise $c->request->{arguments} in 
# Catalyst::Dispatcher::_do_forward, rather than using save and restore,
# as otherwise, the calling $c->detach on an action which says
# die $Catalyst:DETACH causes the request arguments to not get restored,
# and therefore sub gorch gets the wrong string $frozjob parameter.

# Please feel free to break this behavior once a sane hook for safely
# executing another action from the dispatcher (i.e. wrapping actions)
# is present, so that the Authorization::ACL plugin can be re-written
# to not be full of such crazy shit.
{
    package ACLTestApp;
    use Test::More;

    use strict;
    use warnings;
    use MRO::Compat;
    use Scalar::Util ();

    use base qw/Catalyst Catalyst::Controller/;
    use Catalyst qw//;

    sub execute {
        my $c = shift;
        my ( $class, $action ) = @_;

        if ( Scalar::Util::blessed($action)
            and $action->name ne "foobar" ) {
              eval { $c->detach( 'foobar', [$action, 'foo'] ) };
        }

        $c->next::method( @_ );
    }

    sub foobar : Private {
        die $Catalyst::DETACH;
    }

    sub gorch : Local {
        my ( $self, $c, $frozjob ) = @_;
        is $frozjob, 'wozzle';
        $c->res->body("gorch");
    }

    __PACKAGE__->setup;
}

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Catalyst::Test 'ACLTestApp';
use Test::More tests => 1;

request('http://localhost/gorch/wozzle');
