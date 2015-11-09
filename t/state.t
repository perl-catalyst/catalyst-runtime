use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  MyApp::Controller::Root->config(namespace=>'');

  sub begin :Action {
    my ($self, $c) = @_;
    Test::More::is($c->state, 0);
    return 'begin';
  }

  sub auto :Action {
    my ($self, $c) = @_;
    # Even if a begin returns something, we kill it.  Need to
    # do this since there's actually people doing detach in
    # auto and expect that to work the same as 0.
    Test::More::is($c->state, '0');
    return 'auto';

  }

  sub base :Chained('/') PathPrefix CaptureArgs(0) {
    my ($self, $c) = @_;
    Test::More::is($c->state, 'auto');
    return 10;
  }

    sub one :Chained('base') PathPart('') CaptureArgs(0) {
      my ($self, $c) = @_;
      Test::More::is($c->state, 10);
      return 20;
    }

      sub two :Chained('one') PathPart('') Args(1) {
        my ($self, $c, $arg) = @_;
        Test::More::is($c->state, 20);
        my $ret = $c->forward('forward2');
        Test::More::is($ret, 25);
        Test::More::is($c->state, 25);
        return 30;
      }

  sub end :Action {
    my ($self, $c) = @_;
    Test::More::is($c->state, 30);
    my $ret = $c->forward('forward1');
    Test::More::is($ret, 100);
    Test::More::is($c->state, 100);
    $c->detach('detach1');
  }

  sub forward1 :Action {
    my ($self, $c) = @_;
    Test::More::is($c->state, 30);
    return 100;
  }

  sub forward2 :Action {
    my ($self, $c) = @_;
    Test::More::is($c->state, 20);
    return 25;
  }

  sub detach1 :Action {
    my ($self, $c) = @_;
    Test::More::is($c->state, 100);
  }

  package MyApp;
  use Catalyst;

  MyApp->config(show_internal_actions=>1);
  MyApp->setup;
}

use Catalyst::Test 'MyApp';

{
  ok my $res = request "/100";
}

done_testing;
