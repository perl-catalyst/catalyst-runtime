package TestApp::ControllerBase::OtherRoot;

use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw/Catalyst::Controller/; }

sub chain_middle : CaptureArgs(0) PathPart('') Chained('chain_first') {}

__PACKAGE__->meta->make_immutable;

1;
