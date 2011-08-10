package TestAppCustomContainer::Model::Foo;
use Moose;
extends 'Catalyst::Model';
with 'TestAppCustomContainer::Role::ACCEPT_CONTEXT';

has bar_got_it => (
    traits  => ['Counter'],
    is      => 'ro',
    isa     => 'Int',
    default => 0,
    handles => {
        inc_bar_got_it => 'inc',
    },
);

has baz_got_it => (
    traits  => ['Counter'],
    is      => 'ro',
    isa     => 'Int',
    default => 0,
    handles => {
        inc_baz_got_it => 'inc',
    },
);

sub COMPONENT { shift->new() }

__PACKAGE__->meta->make_immutable;

no Moose;
1;
