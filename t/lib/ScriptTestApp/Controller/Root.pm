package ScriptTestApp::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub default : Chained('/') PathPart('') Args() {}

1;

