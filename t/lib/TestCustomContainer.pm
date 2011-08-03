package TestCustomContainer;
use Moose;
use namespace::autoclean;
use Test::More;

has app_name => (
    is => 'ro',
    isa => 'Str',
    default => 'TestAppCustomContainer',
);

has container_class => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has sugar => (
    is => 'ro',
    isa => 'Int',
);

sub BUILD {
    my $self = shift;

    $ENV{TEST_APP_CURRENT_CONTAINER} = $self->container_class;

    require Catalyst::Test;
    Catalyst::Test->import($self->app_name);

    is(get('/container_class'), $self->container_class);
    is(get('/container_isa'), $self->container_class);

    done_testing;
}

sub _build_container_class {
    my $self = shift;

    my $sugar = $self->sugar ? '' : 'No';

    return $self->app_name . "::${sugar}SugarContainer";
}

__PACKAGE__->meta->make_immutable;

1;
