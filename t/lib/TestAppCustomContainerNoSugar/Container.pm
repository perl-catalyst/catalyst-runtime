package TestAppCustomContainerNoSugar::Container;
use Moose;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;
    $self->get_sub_container('component')->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name         => 'model_Baz',
            class        => 'TestAppCustomContainerNoSugar::Model::Baz',
            lifecycle    => 'InstancePerContext',
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
}

1;
