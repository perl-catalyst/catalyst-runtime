package TestAppCustomContainer;
use Moose;
use Catalyst;
extends 'Catalyst';
use namespace::autoclean;

__PACKAGE__->config(
    container_class => $ENV{TEST_APP_CURRENT_CONTAINER}
) if $ENV{TEST_APP_CURRENT_CONTAINER};

__PACKAGE__->setup;

1;
