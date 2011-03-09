package TestAppSetupRecursion;

use Moose;
use namespace::autoclean;

extends 'Catalyst';

our $SetupCount = 0;
# Content of the sub is irrelevant, the bug is that it's existence triggers
# infinite recursion.
after setup => sub {
    $SetupCount++;
};

__PACKAGE__->setup;
