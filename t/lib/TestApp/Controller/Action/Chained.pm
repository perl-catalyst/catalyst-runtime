package TestApp::Controller::Action::Chained;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

sub begin :Private { }

#
#   TODO
#   :Chained('') defaulting to controller namespace
#   :Chained('..') defaulting to action in controller above
#   :Chained == Chained('/')
#

#
#   Simple parent/child action test
#
sub foo  :PathPart('chained/foo')  :Captures(1) :Chained('/') { }
sub endpoint  :PathPart('end')  :Chained('/action/chained/foo')  :Args(1) { }

#
#   Parent/child test with two args each
#
sub foo2 :PathPart('chained/foo2') :Captures(2) :Chained('/') { }
sub endpoint2 :PathPart('end2') :Chained('/action/chained/foo2') :Args(2) { }

#
#   Relative specification of parent action
#
sub bar :PathPart('chained/bar') :Chained('/') :Captures(0) { }
sub finale :PathPart('') :Chained('bar') :Args { }

#
#   three chain with concurrent endpoints
#
sub one   :PathPart('chained/one') :Chained('/')                   :Captures(1) { }
sub two   :PathPart('two')         :Chained('/action/chained/one') :Captures(2) { }
sub three_end :PathPart('three')       :Chained('two') :Args(3) { }
sub one_end   :PathPart('chained/one') :Chained('/')   :Args(1) { }
sub two_end   :PathPart('two')         :Chained('one') :Args(2) { }

#
#   Dispatch on number of arguments
#
sub multi1 :PathPart('chained/multi') :Chained('/') :Args(1) { }
sub multi2 :PathPart('chained/multi') :Chained('/') :Args(2) { }

#
#   Roots in an action defined in a higher controller
#
sub higher_root :PathPart('bar') :Chained('/action/chained/foo/higher_root') :Args(1) { }

#
#   Controller -> subcontroller -> controller
#
sub pcp1 :PathPart('chained/pcp1')  :Chained('/')                        :Captures(1) { }
sub pcp3 :Chained('/action/chained/foo/pcp2') :Args(1)     { }

#
#   Dispatch on capture number
#
sub multi_cap1 :PathPart('chained/multi_cap') :Chained('/') :Captures(1) { }
sub multi_cap2 :PathPart('chained/multi_cap') :Chained('/') :Captures(2) { }
sub multi_cap_end1 :PathPart('baz') :Chained('multi_cap1') :Args(0) { }
sub multi_cap_end2 :PathPart('baz') :Chained('multi_cap2') :Args(0) { }

#
#   Priority: Slurpy args vs. chained actions
#
sub priority_a1 :PathPart('chained/priority_a') :Chained('/') :Args { }
sub priority_a2 :PathPart('chained/priority_a') :Chained('/') :Captures(1) { }
sub priority_a2_end :PathPart('end') :Chained('priority_a2') :Args(1) { }

#
#   Priority: Fixed args vs. chained actions
#
sub priority_b1 :PathPart('chained/priority_b') :Chained('/') :Args(3) { }
sub priority_b2 :PathPart('chained/priority_b') :Chained('/') :Captures(1) { }
sub priority_b2_end :PathPart('end') :Chained('priority_b2') :Args(1) { }

#
#   Optional specification of :Args in endpoint
#
sub opt_args :PathPart('chained/opt_args') :Chained('/') { }

#
#   Optional PathPart test -> /chained/optpp/*/opt_pathpart/*
#
sub opt_pp_start :Chained('/') :PathPart('chained/optpp') :Captures(1) { }
sub opt_pathpart :Chained('opt_pp_start') :Args(1) { }

#
#   Optional Args *and* PathPart -> /chained/optall/*/oa/...
#
sub opt_all_start :Chained('/') :PathPart('chained/optall') :Captures(1) { }
sub oa :Chained('opt_all_start') { }

sub end :Private {
  my ($self, $c) = @_;
  my $out = join('; ', map { join(', ', @$_) }
                         ($c->req->captures, $c->req->args));
  $c->res->body($out);
}

1;
