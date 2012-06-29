package TestAppCustomContainer::NoSugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name             => 'SingletonLifeCycle',
            lifecycle        => 'Singleton',
            class            => 'TestAppCustomContainer::Model::SingletonLifeCycle',
            catalyst_component_name => 'TestAppCustomContainer::Model::SingletonLifeCycle',
            dependencies     => {
                catalyst_application => depends_on( '/catalyst_application' ),
            },
        )
    );

    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'RequestLifeCycle',
            lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
            class        => 'TestAppCustomContainer::Model::RequestLifeCycle',
            catalyst_component_name => 'TestAppCustomContainer::Model::RequestLifeCycle',
            dependencies => {
                catalyst_application => depends_on( '/catalyst_application' ),
            },
        )
    );

#    $self->get_sub_container('model')->add_service(
#        Catalyst::IOC::ConstructorInjection->new(
#            name             => 'DependsOnDefaultSetup',
#            class            => 'TestAppCustomContainer::Model::DependsOnDefaultSetup',
#            catalyst_component_name => 'TestAppCustomContainer::Model::DependsOnDefaultSetup',
#            dependencies     => {
#                catalyst_application => depends_on( '/catalyst_application' ),
#                # FIXME - this is what is blowing up everything:
#                # DefaultSetup needs the context. It's not getting it here!
#                foo => depends_on('/model/DefaultSetup'),
#            },
#        )
#    );

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

#    my $fnar_config = $self->resolve(service => 'config')->{'Model::Fnar'} || {};
#    $self->get_sub_container('component')->add_service(
#        Catalyst::IOC::ConstructorInjection->new(
#            name         => 'model_Fnar',
#            lifecycle    => 'Singleton',
#            class        => 'TestAppCustomContainer::External::Class',
#            dependencies => [
#                depends_on( '/catalyst_application' ),
#            ],
#            config => $fnar_config,
#        )
#    );
#    $self->get_sub_container('model')->add_service(
#        Catalyst::IOC::BlockInjection->new(
#            name         => 'model_Fnar',
#            lifecycle    => 'Singleton',
#            dependencies => [
#                depends_on( '/config' ),
#                depends_on( '/component/model_Fnar' ),
#            ],
#            block => sub { shift->param('model_Fnar') },
#        )
#    );
}

__PACKAGE__->meta->make_immutable;

1;
