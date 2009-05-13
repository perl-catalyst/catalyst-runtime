# See t/plugin_new_method_backcompat.t
package TestPluginWithConstructor;
use strict;
use warnings;
sub new {
    my $class = shift;
    return bless $_[0], $class;
}

1;

