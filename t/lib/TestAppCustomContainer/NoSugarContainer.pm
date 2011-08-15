package TestAppCustomContainer::NoSugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    warn("Add SingletonLifeCycle to model");
    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name             => 'SingletonLifeCycle',
            lifecycle        => 'Singleton',
            class            => 'TestAppCustomContainer::Model::SingletonLifeCycle',
            catalyst_component_name => 'TestAppCustomContainer::Model::SingletonLifeCycle',
            dependencies     => {
                application_name => depends_on( '/application_name' ),
                foo => depends_on('/model/DefaultSetup'),
            },
        )
    );

    $self->get_sub_container('model')->add_service(
        # FIXME - i think it should be a ConstructorInjection
        # but only BlockInjection gets ctx parameter
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'Baz',
            lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
            class        => 'TestAppCustomContainer::Model::Baz',
            dependencies => {
                application_name => depends_on( '/application_name' ),
                foo => depends_on('/model/DefaultSetup'),
            },
        )
    );

# Broken deps!?!
#    $self->get_sub_container('model')->add_service(
#        Catalyst::IOC::BlockInjection->new(
#            name         => 'Quux',
#            lifecycle    => 'Singleton',
#            dependencies => [
#                depends_on( '/component/model_Quux' ),
#            ],
#            block => sub { shift->param('model_Bar') },
#        )
#    );

    my $fnar_config = $self->resolve(service => 'config')->{'Model::Fnar'} || {};
    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Fnar',
            lifecycle    => 'Singleton',
            class        => 'TestAppCustomContainer::External::Class',
            dependencies => [
                depends_on( '/application_name' ),
            ],
            config => $fnar_config,
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
