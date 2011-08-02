package TestAppCustomContainerNoSugar::Controller::Root;
use Moose;
BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->meta->make_immutable;
no Moose;
1;
