package TestAppCustomContainer::Role::HoldsFoo;
use Moose::Role;
use Test::More;
use namespace::autoclean;

has foo => (
    is       => 'ro',
#    isa      => 'TestAppCustomContainer::Model::Foo',
#    required => 1,
);

sub BUILD {}

after BUILD => sub {
    my $self = shift;
    ok($self->foo, ref($self) . " got a ->foo");
    isa_ok($self->foo, 'TestAppCustomContainer::Model::DefaultSetup', ref($self) . " isa 'TestAppCustomContainer::Model::DefaultSetup'");
};

1;
