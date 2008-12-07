package CAFCompatTestPlugin;

# This plugin specificially tests an edge case of CAF compat,
# where you load a plugin which uses base CAF, and then override
# a core catalyst accessor (_config in this case)..

# This is what happens if you use the authentication back-compat
# stuff, as C::A::Plugin::Credential::Password is added to the plugin
# list, and the base C::A::C::P class, does the mk_accessors, and
# then the C::P::A class calls the config method before setup finishes...

use strict;
use warnings;

# Note that we don't actually _really_ use CAF here, as MX::Adopt::CAF
# is in place...
use base qw/Class::Accessor::Fast/;

BEGIN {
    __PACKAGE__->mk_accessors(qw/_config/);
}

sub setup {
    my $app = shift;

    $app->config;
    $app->NEXT::setup(@_);
}

1;
