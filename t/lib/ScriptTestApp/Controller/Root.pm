package ScriptTestApp::Controller::Root;
use Moose;
use namespace::clean -except => [ 'meta' ];

BEGIN { extends 'Catalyst::Controller' }

sub default : Chained('/') PathPart('') Args() {}

1;

