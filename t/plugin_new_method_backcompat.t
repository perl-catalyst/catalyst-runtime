# Test that plugins with their own new method don't break applications.

# 5.70 creates all of the request/response structure itself in prepare, 
# and as the new method in our plugin just blesses our args, that works nicely.

# In 5.80, we rely on the new method to appropriately initialise data 
# structures, and therefore we need to inline a new method on MyApp to ensure
# that plugins don't get it wrong for us.

# Also tests method modifiers and etc in MyApp.pm still work as expected.

use FindBin;
use lib "$FindBin::Bin/lib";use Test::More tests => 3;

use Catalyst::Test qw/TestAppPluginWithNewMethod/; # 1 test for adding a modifer not throwing.
BEGIN { warn("COMPILE TIME finished use of Catalyst::Test"); }
ok request('/foo')->is_success; 
is $TestAppPluginWithNewMethod::MODIFIER_FIRED, 1, 'Before modifier was fired correctly.';
