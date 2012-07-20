package TestAppGetAllComponentServices;
use Moose;
extends 'Catalyst';
__PACKAGE__->setup_config;
__PACKAGE__->setup_components;
__PACKAGE__->meta->make_immutable;
1;
