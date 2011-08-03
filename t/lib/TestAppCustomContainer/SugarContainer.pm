package TestAppCustomContainer::SugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;

extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    container $self => as {
        container model => as {
            component Foo => ();
            component Bar => ( dependencies => [ depends_on('/model/Foo') ] );
            component Baz => (
                lifecycle    => '+Catalyst::IOC::LifeCycle::Request',
                dependencies => [
                    depends_on( '/application_name' ),
                    depends_on( '/config' ),
                    depends_on( '/model/Foo' ),
                ],
            );
            component Quux => ( lifecycle => 'Singleton' );
            component Fnar => (
                lifecycle => 'Singleton',
                class     => 'My::External::Class',
                dependencies => [ depends_on('config') ],
            #   ^^ FIXME - gets whole config, not Model::Foo
            #   There should be a 'nice' way to get the 'standard' config
            );
        };
    };
}

__PACKAGE__->meta->make_immutable;

1;
