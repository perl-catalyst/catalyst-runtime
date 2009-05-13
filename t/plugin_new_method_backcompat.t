# Test that plugins with their own new method don't break applications.

# 5.70 creates all of the request/response structure itself in prepare,
# and as the new method in our plugin just blesses our args, that works nicely.

# In 5.80, we rely on the new method to appropriately initialise data
# structures, and therefore we need to inline a new method on MyApp to ensure
# that plugins don't get it wrong for us.

# Also tests method modifiers and etc in MyApp.pm still work as expected.
use Test::More tests => 4;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test qw/TestAppPluginWithConstructor/;
ok request('/foo')->is_success;
is $TestAppPluginWithConstructor::MODIFIER_FIRED, 1, 'Before modifier was fired correctly.';

throws_ok {
    package TestAppBadlyImmutable;
    use Catalyst qw/+TestPluginWithConstructor/;

    TestAppBadlyImmutable->setup;

    __PACKAGE__->meta->make_immutable( inline_constructor => 0 );
}
    qr/\QYou made your application class (TestAppBadlyImmutable) immutable/,
    'An application class that is already immutable but does not inline the constructor dies at ->setup';

