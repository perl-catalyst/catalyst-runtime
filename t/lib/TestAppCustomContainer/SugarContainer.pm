package TestAppCustomContainer::SugarContainer;
use Moose;
use namespace::autoclean;
use Catalyst::IOC;
use Bread::Board qw/ depends_on /;
extends 'Catalyst::IOC::Container';

sub BUILD {
    my $self = shift;
    warn("In build");
    $Catalyst::IOC::customise_container->($self);
}

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
