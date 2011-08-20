package TestAppCustomContainer;
use Moose;
use Catalyst;
extends 'Catalyst';
use namespace::autoclean;

confess("No default container") unless $ENV{TEST_APP_CURRENT_CONTAINER};

__PACKAGE__->config(
    container_class => $ENV{TEST_APP_CURRENT_CONTAINER}
);

__PACKAGE__->setup;

1;
