package TestAppCustomContainer::Model::Baz;
use Moose;
extends 'Catalyst::Model';
with 'TestAppCustomContainer::Role::HoldsFoo',
     'TestAppCustomContainer::Role::ACCEPT_CONTEXT';

sub BUILD {
    my ( $self ) = @_;

    $self->foo->inc_baz_got_it;
}

__PACKAGE__->meta->make_immutable;

no Moose;
1;
