package TestAppCustomContainer::SugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;
extends 'Catalyst::IOC::Container';

container {
    model {
        component 'SingletonLifeCycle' => (
                class        => 'TestAppCustomContainer::Model::SingletonLifeCycle',
                lifecycle    => 'Singleton',
        );
        component 'RequestLifeCycle' => (
                class        => 'TestAppCustomContainer::Model::RequestLifeCycle',
                lifecycle    => 'Request',
        );
    };
};

__PACKAGE__->meta->make_immutable;

1;
