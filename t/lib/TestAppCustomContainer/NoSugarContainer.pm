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
            lifecycle    => 'Singleton',
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
            lifecycle    => 'Singleton',
            dependencies => [
                Bread::Board::Dependency->new(
                    service_path => 'Foo',

                    # FIXME - obviously this is a mistake
                    # what to do with ctx here?
                    # I have no way to get $s here, do I?
                    service_params => {
                        ctx => +{},
                        accept_context_args => [ +{} ],
                    },
                ),
                depends_on( '/component/model_Bar' ),
            ],
            block => sub {
                my $s   = shift;

                my $foo = $s->param('Foo');
                $foo->inc_bar_got_it;

                return $s->param('model_Bar');
            },
        )
    );

    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Baz',
            class        => 'TestAppCustomContainer::Model::Baz',
            lifecycle    => 'Singleton',

            # while it doesn't fully work
            #lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
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
                Bread::Board::Dependency->new(
                    service_path => 'Foo',

                    # FIXME - same as above
                    service_params => {
                        ctx => +{},
                        accept_context_args => [ +{} ],
                    },
                ),
                depends_on( '/component/model_Baz' ),
            ],
            block => sub {
                my $s   = shift;

                my $foo = $s->param('Foo');
                $foo->inc_baz_got_it;

                return $s->param('model_Baz');
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
