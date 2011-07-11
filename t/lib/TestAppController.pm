package TestAppController;
use Moose;
use namespace::autoclean;
use Catalyst;

extends 'Catalyst';

__PACKAGE__->setup;
__PACKAGE__->meta->make_immutable;

1;
