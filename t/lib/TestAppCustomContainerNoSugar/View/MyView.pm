package TestAppCustomContainerNoSugar::View::MyView;
use Moose;
extends 'Catalyst::View';

__PACKAGE__->meta->make_immutable;

no Moose;
1;
