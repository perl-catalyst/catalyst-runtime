package TestApp::Model::Generating;
use Moose;
extends 'Catalyst::Model';

sub BUILD {
    Class::MOP::Class->create(
        'TestApp::Model::Generated' => (
            methods => {
                foo => sub { 'foo' }
            }
        )
    );
}

sub expand_modules {
    return ('TestApp::Model::Generated');
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
