package TestAppCustomContainer::Role::HoldsFoo;
use Moose::Role;
use namespace::autoclean;

has foo => (
    is       => 'ro',
    isa      => 'TestAppCustomContainer::Model::Foo',
    required => 1,
);

sub COMPONENT {
    my ( $self, $ctx, $config ) = @_;

    # FIXME - is this how should I get model Foo?
    return $self->new(
        foo => $ctx->model('Foo'),
    );
}

1;
