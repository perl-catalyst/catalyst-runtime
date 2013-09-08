package Catalyst::Plugin::Test::MangleDollarUnderScore;
use strict;
use warnings;

# FIXME - should proably use utf8??
our $VERSION = 0.1; # Make is_class_loaded happy

# Class::Load::load_class($_) can hurt you real hard.
BEGIN { $_ = q{
mst sayeth, Class::Load::load_class($_) will ruin your life
rafl spokeh "i ♥ my $_"',
and verrily forsooth, t0m made tests
and yea, there was fail' }; }

1;
__END__

