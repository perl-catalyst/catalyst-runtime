# Test that plugins with their own new method don't break applications.

# 5.70 creates all of the request/response structure itself in prepare,
# and as the new method in our plugin just blesses our args, that works nicely.

# In 5.80, we rely on the new method to appropriately initialise data
# structures, and therefore we need to inline a new method on MyApp to ensure
# that plugins don't get it wrong for us.

# Also tests method modifiers and etc in MyApp.pm still work as expected.
use Test::More tests => 8;
use Test::Exception;
use Moose::Util qw/find_meta/;
use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test qw/TestAppPluginWithConstructor/;
ok find_meta('TestAppPluginWithConstructor')->is_immutable,
    'Am immutable after use';

ok request('/foo')->is_success, 'Can get /foo';
is $TestAppPluginWithConstructor::MODIFIER_FIRED, 1, 'Before modifier was fired correctly.';

my $warning;
local $SIG{__WARN__} = sub { $warning = $_[0] };
eval "use TestAppBadlyImmutable;";
like $warning, qr/\QYou made your application class (TestAppBadlyImmutable) immutable/,
    'An application class that is already immutable but does not inline the constructor warns at ->setup';

