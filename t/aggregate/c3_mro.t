use strict;
use warnings;

use Test::More;
require Catalyst;
require Module::Pluggable::Object;
use MRO::Compat;

# Get a list of all Catalyst:: packages in blib via M::P::O
my @cat_mods;
{
  # problem with @INC on win32, see:
  # http://rt.cpan.org/Ticket/Display.html?id=26452
  if ($^O eq 'MSWin32') { require Win32; Win32::GetCwd(); }

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
  eval { mro::get_linear_isa($cat_mod, 'c3') };
  ok(!$@, "calculateMRO for $cat_mod: $@");
}

