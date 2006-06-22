package TestApp::Controller::Action::ChildOf;

use strict;
use warnings;

use base qw/Catalyst::Controller/;

sub begin :Private { }

sub foo :PathPart('childof/foo') :Captures(1) :ChildOf('/') { }

sub bar :PathPart('childof/bar') :ChildOf('/') { }

sub endpoint :PathPart('end') :ChildOf('/action/childof/foo') :Args(1) { }

sub finale :ChildOf('bar') :Args { }

sub end :Private {
  my ($self, $c) = @_;
  my $out = join('; ', map { join(', ', @$_) }
                         ($c->req->captures, $c->req->args));
  $c->res->body($out);
}

1;
