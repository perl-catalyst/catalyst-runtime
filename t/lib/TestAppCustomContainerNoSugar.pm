package TestAppCustomContainerNoSugar;
use Moose;
use Catalyst;
extends 'Catalyst';
use namespace::autoclean;

__PACKAGE__->config(
    container_class => 'TestAppCustomContainerNoSugar::Container',
);

__PACKAGE__->setup;

1;
