package TestApp::ControllerBase::Middle;

use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw/TestApp::ControllerBase::Root/; }

__PACKAGE__->meta->make_immutable;

1;
