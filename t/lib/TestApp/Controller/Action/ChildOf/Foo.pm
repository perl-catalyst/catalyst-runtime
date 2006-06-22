package TestApp::Controller::Action::ChildOf::Foo;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

sub spoon :PathPart :ChildOf('') :Args(0) { }

1;
