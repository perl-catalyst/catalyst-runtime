package Catalyst::BlockInjection;
use Moose;

extends 'Bread::Board::BlockInjection';

with 'Catalyst::Service::WithContext';

__PACKAGE__->meta->make_immutable;

no Moose;
1;
