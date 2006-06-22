package TestApp::Controller::Action::ChildOf::Foo;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

#
#   Child of current namespace
#
sub spoon :ChildOf('') :Args(0) { }

#
#   Root for a action in a "parent" controller
#
sub higher_root :PathPart('childof/higher_root') :ChildOf('/') :Captures(1) { }

#
#   Parent controller -> this subcontroller -> parent controller test
#
sub pcp2 :ChildOf('/action/childof/pcp1') :Captures(1) { }

#
#   Controllers not in parent/child relation. This tests the end.
#
sub cross2 :PathPart('end') :ChildOf('/action/childof/bar/cross1') :Args(1) { }

1;
