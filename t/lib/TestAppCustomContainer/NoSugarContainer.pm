package TestAppCustomContainer::NoSugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    $self->get_sub_container('component')->add_service(
        # Catalyst::IOC::ConstructorInjection gives the constructor the wrong
        # parameters
        Bread::Board::ConstructorInjection->new(
            name             => 'model_Bar',
            lifecycle        => 'Singleton',
            class            => 'TestAppCustomContainer::Model::Bar',
            constructor_name => 'new',
            dependencies     => {
                application_name => depends_on( '/application_name' ),
                config => depends_on( '/config' ),
                foo => Bread::Board::Dependency->new(
                    service_name => 'foo',
                    service_path => '/model/Foo',

                    # FIXME - obviously this is a mistake
                    # what to do with ctx here?
                    # I have no way to get $s here, do I?
                    service_params => {
                        ctx => +{},
                        accept_context_args => [ +{} ],
                    },
                ),
            },
        )
    );
    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'Bar',
            lifecycle    => 'Singleton',
            dependencies => [
                depends_on( '/component/model_Bar' ),
            ],
            block => sub {
                shift->param('model_Bar');
            },
        )
    );

    # FIXME - this is to avoid the default service to be added
    # if that happened, the app would die
    $self->get_sub_container('component')->add_service(
        service model_Baz => 'TestAppCustomContainer::Model::Baz',
    );
    $self->get_sub_container('model')->add_service(
        # FIXME - i think it should be a ConstructorInjection
        # but only BlockInjection gets ctx parameter
        Catalyst::IOC::BlockInjection->new(
            name         => 'Baz',
            lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
            dependencies => [
                Bread::Board::Dependency->new(
                    service_name => 'foo',
                    service_path => 'Foo',

                    # FIXME - same as above
                    service_params => {
                        ctx => +{},
                        accept_context_args => [ +{} ],
                    },
                ),
            ],
            block => sub {
                TestAppCustomContainer::Model::Baz->new(foo => shift->param('foo'));
            },
        )
    );

    $self->get_sub_container('model')->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => 'Quux',
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
            class        => 'TestAppCustomContainer::External::Class',
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
