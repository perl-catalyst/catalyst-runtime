package Catalyst::ConstructorInjection;
use Moose;

extends 'Bread::Board::ConstructorInjection';

with 'Catalyst::Service::WithContext';

__PACKAGE__->meta->make_immutable;

no Moose;
1;
