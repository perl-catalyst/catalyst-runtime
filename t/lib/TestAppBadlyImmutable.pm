package TestAppBadlyImmutable;
use Catalyst qw/+TestPluginWithConstructor/;

use base qw/Class::Accessor Catalyst/;

use Test::More;

__PACKAGE__->setup;

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
ok __PACKAGE__->meta->is_immutable, 'Am now immutable';

1;

