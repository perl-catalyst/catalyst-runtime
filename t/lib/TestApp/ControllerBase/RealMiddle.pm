package TestApp::ControllerBase::RealMiddle;

use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw/TestApp::ControllerBase::OtherRoot/; }

__PACKAGE__->meta->make_immutable;

1;
