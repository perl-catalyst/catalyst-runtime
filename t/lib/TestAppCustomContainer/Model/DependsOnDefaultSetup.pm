package TestAppCustomContainer::Model::DependsOnDefaultSetup;
use Moose;
extends 'Catalyst::Model';
#with 'TestAppCustomContainer::Role::HoldsFoo';

__PACKAGE__->meta->make_immutable;

no Moose;
1;

