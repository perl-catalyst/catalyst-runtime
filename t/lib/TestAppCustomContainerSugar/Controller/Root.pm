package TestAppCustomContainerSugar::Controller::Root;
use Moose;

BEGIN { extends 'TestAppCustomContainer::Controller::Root' }
no Moose;

__PACKAGE__->meta->make_immutable;
1;

