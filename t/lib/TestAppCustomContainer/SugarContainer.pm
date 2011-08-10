package TestAppCustomContainer::SugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;
use Bread::Board;
extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;

    warn("Add Bar to model");
    $self->get_sub_container('model')->add_service(
        component(
            'Bar' =>
                class        => 'TestAppCustomContainer::Model::Bar',
                dependencies => { foo => depends_on('/model/DefaultSetup') },
        )
    );
}

__PACKAGE__->meta->make_immutable;

1;
