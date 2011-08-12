package TestAppCustomContainer::SugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;
extends 'Catalyst::IOC::Container';

container {
    model {
        component(
            'Bar' =>
                class        => 'TestAppCustomContainer::Model::Bar',
                dependencies => { foo => depends_on('/model/DefaultSetup') },
        );
    };
};

__PACKAGE__->meta->make_immutable;

1;
