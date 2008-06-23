use strict;
use warnings;

use Test::More;
require Catalyst;
require Module::Pluggable::Object;

eval "require Class::C3";
plan skip_all => "This test requires Class::C3" if $@;

# Get a list of all Catalyst:: packages in blib via M::P::O
my @cat_mods;
{
  local @INC = grep {/blib/} @INC;
  @cat_mods = (
    'Catalyst',
    Module::Pluggable::Object->new(search_path => ['Catalyst'])->plugins,
  );
}

# plan one test per found package name
plan tests => scalar @cat_mods;

# Try to calculate the C3 MRO for each package
#
# In the case that the initial require fails (as in
# Catalyst::Engine::FastCGI when FCGI is not installed),
# the calculateMRO eval will not error out, which is
# effectively a test skip.
#
foreach my $cat_mod (@cat_mods) {
  eval " require $cat_mod ";
  eval { Class::C3::calculateMRO($cat_mod) };
  ok(!$@, "calculateMRO for $cat_mod: $@");
}

