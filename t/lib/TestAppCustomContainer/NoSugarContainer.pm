package TestAppCustomContainer::NoSugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Bar',
            class        => 'TestAppCustomContainer::Model::Bar',
            dependencies => [
                depends_on( '/application_name' ),
                depends_on( '/config' ),
                depends_on( '/model/Foo' ),
            ],
        )
    );
    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'Bar',
            dependencies => [
                depends_on( '/model/Foo' ),
                depends_on( '/component/model_Bar' ),
            ],
            block => sub {
                my $s        = shift;
                my $foo      = $s->param('Foo');
                my $instance = $s->param('model_Bar');
                return $instance;
            },
        )
    );

    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Baz',
            class        => 'TestAppCustomContainer::Model::Baz',
# t0m - I'm fine with this - sugar can just s/Request/+Catalyst::IOC::LifeCycle::Request/
#       Also, 'Request' is fine as a name for a lifecycle IMO.
# FIXME - it should simply be Request (or InstancePerRequest, etc)
# see Bread/Board/Service.pm line 47
            lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
            dependencies => [
                depends_on( '/application_name' ),
                depends_on( '/config' ),
                depends_on( '/model/Foo' ),
            ],
        )
    );
    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'Baz',
            dependencies => [
                depends_on( '/model/Foo' ),
                depends_on( '/component/model_Baz' ),
            ],
            block => sub {
                my $s        = shift;
                my $foo      = $s->param('Foo');
                my $instance = $s->param('model_Baz');
                return $instance;
            },
        )
    );

    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'Quux',

# FIXME - it should probably be our
# Catalyst::IOC::LifeCycle::Singleton
# t0m - I think normal Singleton is fine here, it's per app lifetime.
            lifecycle    => 'Singleton',
            dependencies => [
                depends_on( '/component/model_Quux' ),
            ],
            block => sub { shift->param('model_Bar') },
        )
    );

    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Fnar',
            lifecycle    => 'Singleton',
            class        => 'My::External::Class',
            dependencies => [
                depends_on( '/application_name' ),
                depends_on( '/config' ),
            ],
        )
    );
    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'model_Fnar',
            lifecycle    => 'Singleton',
            dependencies => [
                depends_on( '/config' ),
                depends_on( '/component/model_Fnar' ),
            ],
            block => sub { shift->param('model_Fnar') },
        )
    );
}

__PACKAGE__->meta->make_immutable;

1;
