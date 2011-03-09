package TestAppSetupRecursionImmutable;

use Moose;
use namespace::autoclean;

extends 'Catalyst';

our $SetupCount = 0;
# Content of the sub is irrelevant, the bug is that it's existence triggers
# infinite recursion.
after setup => sub {
    $SetupCount++;
};

__PACKAGE__->meta->make_immutable( replace_constructor => 1 );

__PACKAGE__->setup;
