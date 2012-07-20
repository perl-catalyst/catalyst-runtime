use warnings;
use strict;
use Test::More;
use Moose::Meta::Class;
use Data::Dumper;

Moose::Meta::Class->create( MyModel => (
    superclasses => ['Catalyst::Model'],
));

Moose::Meta::Class->create( TestAppComponent => (
    superclasses => ['Catalyst'],
));
TestAppComponent->setup_log;
TestAppComponent->setup_config;

ok(TestAppComponent->components({ Test => 'MyModel' }));

# no warnings, and no components dumped
diag(Dumper(TestAppComponent->components()));

done_testing;
