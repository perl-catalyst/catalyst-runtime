package TestAppCustomContainer::Model::Baz;
use Moose;
extends 'Catalyst::Model';
with 'TestAppCustomContainer::Role::HoldsFoo',
     'TestAppCustomContainer::Role::ACCEPT_CONTEXT';

__PACKAGE__->meta->make_immutable;

no Moose;
1;
