package TestApp::Controller::Action::ChildOf;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

sub begin :Private { }

sub foo  :PathPart('childof/foo')  :Captures(1) :ChildOf('/') { }
sub foo2 :PathPart('childof/foo2') :Captures(2) :ChildOf('/') { }

sub bar :PathPart('childof/bar') :ChildOf('/') { }

sub endpoint  :PathPart('end')  :ChildOf('/action/childof/foo')  :Args(1) { }
sub endpoint2 :PathPart('end2') :ChildOf('/action/childof/foo2') :Args(2) { }

sub finale :ChildOf('bar') :Args { }

sub one   :PathPart('childof/one') :ChildOf('/')                   :Captures(1) { }
sub two   :PathPart('two')         :ChildOf('/action/childof/one') :Captures(2) { }

sub three_end :PathPart('three')       :ChildOf('two') :Args(3) { }
sub one_end   :PathPart('childof/one') :ChildOf('/')   :Args(1) { }
sub two_end   :PathPart('two')         :ChildOf('one') :Args(2) { }

sub multi1 :PathPart('childof/multi') :ChildOf('/') :Args(1) { }
sub multi2 :PathPart('childof/multi') :ChildOf('/') :Args(2) { }

sub end :Private {
  my ($self, $c) = @_;
  my $out = join('; ', map { join(', ', @$_) }
                         ($c->req->captures, $c->req->args));
  $c->res->body($out);
}

1;
