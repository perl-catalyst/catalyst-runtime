package TestAppSetupHome;
use Moose;
extends 'Catalyst';

__PACKAGE__->setup;
__PACKAGE__->meta->make_immutable;
1;
