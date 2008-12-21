use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 1;
use Test::Exception;

# Force a stack trace.
use Carp;
$SIG{__DIE__} = \&Carp::confess;

{
    package CDICompatTestApp;
    use Catalyst qw/
	    +CDICompatTestPlugin
    /;
    # Calling ->config here (before we call setup). With CDI/Cat 5.70 this
    # causes *CDICompatTestApp::_config to have a class data accessor created.
    
    # If this doesn't happen, then later when we've added CDICompatTestPlugin
    # to @ISA, we fail in the overridden ->setup method when we call ->config
    # again, as we get the CAF accessor from CDICompatTestPlugin, not the one
    # created in this package as a side-effect of this call. :-(
    __PACKAGE__->config;
}

lives_ok {
    CDICompatTestApp->setup;
} 'Setup app with plugins which says use base qw/Class::Accessor::Fast/';

