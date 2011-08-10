package TestAppCustomContainer::Role::HoldsFoo;
use Moose::Role;
use namespace::autoclean;

has foo => (
    is       => 'ro',
    isa      => 'TestAppCustomContainer::Model::Foo',
    required => 1,
);

1;
