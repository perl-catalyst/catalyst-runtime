package TestAppCustomContainerNoSugar::Model::Baz;
use Moose;
extends 'Catalyst::Model';

__PACKAGE__->meta->make_immutable;

no Moose;
1;
