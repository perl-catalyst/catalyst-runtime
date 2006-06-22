package TestApp::Controller::Action::ChildOf;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

sub begin :Private { }

#
#   Simple parent/child action test
#
sub foo  :PathPart('childof/foo')  :Captures(1) :ChildOf('/') { }
sub endpoint  :PathPart('end')  :ChildOf('/action/childof/foo')  :Args(1) { }

#
#   Parent/child test with two args each
#
sub foo2 :PathPart('childof/foo2') :Captures(2) :ChildOf('/') { }
sub endpoint2 :PathPart('end2') :ChildOf('/action/childof/foo2') :Args(2) { }

#
#   Relative specification of parent action
#
sub bar :PathPart('childof/bar') :ChildOf('/') :Captures(0) { }
sub finale :ChildOf('bar') :Args { }

#
#   three chain with concurrent endpoints
#
sub one   :PathPart('childof/one') :ChildOf('/')                   :Captures(1) { }
sub two   :PathPart('two')         :ChildOf('/action/childof/one') :Captures(2) { }
sub three_end :PathPart('three')       :ChildOf('two') :Args(3) { }
sub one_end   :PathPart('childof/one') :ChildOf('/')   :Args(1) { }
sub two_end   :PathPart('two')         :ChildOf('one') :Args(2) { }

#
#   Dispatch on number of arguments
#
sub multi1 :PathPart('childof/multi') :ChildOf('/') :Args(1) { }
sub multi2 :PathPart('childof/multi') :ChildOf('/') :Args(2) { }

#
#   Roots in an action defined in a higher controller
#
sub higher_root :PathPart('bar') :ChildOf('/action/childof/foo/higher_root') :Args(1) { }

#
#   Controller -> subcontroller -> controller
#
sub pcp1 :PathPart('childof/pcp1')  :ChildOf('/')                        :Captures(1) { }
sub pcp3 :PathPart                  :ChildOf('/action/childof/foo/pcp2') :Args(1)     { }

#
#   Dispatch on capture number
#
sub multi_cap1 :PathPart('childof/multi_cap') :ChildOf('/') :Captures(1) { }
sub multi_cap2 :PathPart('childof/multi_cap') :ChildOf('/') :Captures(2) { }
sub multi_cap_end1 :PathPart('baz') :ChildOf('multi_cap1') :Args(0) { }
sub multi_cap_end2 :PathPart('baz') :ChildOf('multi_cap2') :Args(0) { }

#
#   Priority: Slurpy args vs. chained actions
#
sub priority_a1 :PathPart('childof/priority_a') :ChildOf('/') :Args { }
sub priority_a2 :PathPart('childof/priority_a') :ChildOf('/') :Captures(1) { }
sub priority_a2_end :PathPart('end') :ChildOf('priority_a2') :Args(1) { }

#
#   Priority: Fixed args vs. chained actions
#
sub priority_b1 :PathPart('childof/priority_b') :ChildOf('/') :Args(3) { }
sub priority_b2 :PathPart('childof/priority_b') :ChildOf('/') :Captures(1) { }
sub priority_b2_end :PathPart('end') :ChildOf('priority_b2') :Args(1) { }

#
#   Optional specification of :Args in endpoint
#
sub opt_args :PathPart('childof/opt_args') :ChildOf('/') { }

sub end :Private {
  my ($self, $c) = @_;
  my $out = join('; ', map { join(', ', @$_) }
                         ($c->req->captures, $c->req->args));
  $c->res->body($out);
}

1;
