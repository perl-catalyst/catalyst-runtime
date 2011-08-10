package TestAppCustomContainer;
use Moose;
use Catalyst;
extends 'Catalyst';
use namespace::autoclean;

 confess("No default container") unless $ENV{TEST_APP_CURRENT_CONTAINER};
Class::MOP::load_class($ENV{TEST_APP_CURRENT_CONTAINER}); # FIXME!
# Custom container name is silently ignored if the class doesn't exist!
__PACKAGE__->config(
    container_class => $ENV{TEST_APP_CURRENT_CONTAINER}
);

__PACKAGE__->setup;

1;
