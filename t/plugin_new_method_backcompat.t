# Test that plugins with their own new method don't break applications.

# 5.70 creates all of the request/response structure itself in prepare, 
# and as the new method in our plugin just blesses our args, that works nicely.

# In 5.80, we rely on the new method to appropriately initialise data 
# structures, and therefore we need to inline a new method on MyApp to ensure
# that plugins don't get it wrong for us.

# Also tests method modifiers and etc in MyApp.pm still work as expected.
use Test::More tests => 3;

{
    package NewTestPlugin;
    use strict;
    use warnings;
    sub new { 
        my $class = shift;
        return bless $_[0], $class; 
    }
}

{   # This is all in the same file so that the setup method on the 
    # application is called at runtime, rather than at compile time.
    # This ensures that the end of scope hook has to happen at runtime
    # correctly, otherwise the test will fail (ergo the switch from
    # B::Hooks::EndOfScope to Sub::Uplevel)
    package TestAppPluginWithNewMethod;
    use Test::Exception;
    use Catalyst qw/+NewTestPlugin/;

    sub foo : Local {
        my ($self, $c) = @_;
        $c->res->body('foo');
    }

    use Moose; # Just testing method modifiers still work.
    __PACKAGE__->setup;
    our $MODIFIER_FIRED = 0;

    lives_ok {
        before 'dispatch' => sub { $MODIFIER_FIRED = 1 }
    } 'Can apply method modifier';
    no Moose;
}

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test qw/TestAppPluginWithNewMethod/;
ok request('/foo')->is_success; 
is $TestAppPluginWithNewMethod::MODIFIER_FIRED, 1, 'Before modifier was fired correctly.';
