package TestApp::Controller::Action::ChildOf::Bar;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

#
#   Redispatching between controllers that are not in a parent/child
#   relation. This is the root.
#
sub cross1 :PathPart('childof/cross') :Captures(1) :ChildOf('/') { }

1;
