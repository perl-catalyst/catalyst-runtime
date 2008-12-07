use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 1;
use Test::Exception;

# Force a stack trace.
use Carp;
$SIG{__DIE__} = \&Carp::confess;

{
    package CAFCompatTestApp;
    use Catalyst qw/
	    +CAFCompatTestPlugin
    /;
}

TODO: {
    local $TODO = 'The overridden setup in CAFCompatTestApp + the overridden accessor causes destruction';
    lives_ok {
        CAFCompatTestApp->setup;
    } 'Setup app with plugins which says use base qw/Class::Accessor::Fast/';
}
