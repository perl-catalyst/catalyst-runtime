package TestApp::Controller::Action::Chained::Foo;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

#
#   Child of current namespace
#
sub spoon :Chained('') :Args(0) { }

#
#   Root for a action in a "parent" controller
#
sub higher_root :PathPart('chained/higher_root') :Chained('/') :Captures(1) { }

#
#   Parent controller -> this subcontroller -> parent controller test
#
sub pcp2 :Chained('/action/chained/pcp1') :Captures(1) { }

#
#   Controllers not in parent/child relation. This tests the end.
#
sub cross2 :PathPart('end') :Chained('/action/chained/bar/cross1') :Args(1) { }

1;
