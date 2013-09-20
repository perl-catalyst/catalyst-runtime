# See t/plugin_new_method_backcompat.t
package TestAppPluginWithConstructor;
use Test::More;
use Test::Fatal;
use Catalyst qw/+TestPluginWithConstructor/;
use Moose;
extends qw/Catalyst/;

__PACKAGE__->setup;
our $MODIFIER_FIRED = 0;

is exception {
    before 'dispatch' => sub { $MODIFIER_FIRED = 1 }
}, undef, 'Can apply method modifier';
no Moose;

our $IS_IMMUTABLE_YET = __PACKAGE__->meta->is_immutable;
ok !$IS_IMMUTABLE_YET, 'I am not immutable yet';

1;

