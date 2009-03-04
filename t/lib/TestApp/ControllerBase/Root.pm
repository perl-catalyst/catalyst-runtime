package TestApp::ControllerBase::Root;

use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw/Catalyst::Controller/; }

sub chain_root : Chained('/') PathPrefix CaptureArgs(0) {}

sub chain_end : Chained('chain_middle') Args(0) {}

__PACKAGE__->meta->make_immutable;

1;
