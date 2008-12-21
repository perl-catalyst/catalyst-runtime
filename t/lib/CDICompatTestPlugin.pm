package CDICompatTestPlugin;

# This plugin specificially tests an edge case of C::D::I compat,
# where you load a plugin which creates an accessor with the same
# name as a class data accessor (_config in this case)..

# This is what happens if you use the authentication back-compat
# stuff, as C::A::Plugin::Credential::Password is added to the plugin
# list, and that uses base C::A::C::P class, does the mk_accessors.

# If a class data method called _config hasn't been created in 
# MyApp ($app below), then our call to ->config gets our accessor
# (rather than the class data one), and we fail..

use strict;
use warnings;
use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/_config/);

sub setup {
    my $app = shift;

    $app->config;
    $app->NEXT::setup(@_);
}

1;
