use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  MyApp::Controller::Root->config(namespace=>'');

  sub could_throw :Private {
    my ($self, $c) = @_;
    if ($c->req->args->[0] eq 'y') {
      die 'Bad stuff happened';
    }
    else {
      return 5;
    }
  }

  sub do_throw :Local {
    my ($self, $c) = @_;

    my $ret = $c->forward('/could_throw/y');
    Test::More::is($c->state, 0, 'Throwing: state is correct');
    Test::More::is($ret, 0, 'Throwing: return is correct');
    Test::More::ok($c->has_errors, 'Throwing: has errors');
  }

  sub dont_throw :Local {
    my ($self, $c) = @_;

    my $ret = $c->forward('/could_throw/n');
    Test::More::is($c->state, 5, 'Not throwing: state is correct');
    Test::More::is($ret, 5, 'Not throwing: return is correct');
    Test::More::ok(!$c->has_errors, 'Throwing: no errors');
  }

  package MyApp;
  use Catalyst;

  MyApp->config(show_internal_actions=>1);
  MyApp->setup('-Log=fatal');
}

use Catalyst::Test 'MyApp';

{
  my ($res, $c);

  ctx_request("/dont_throw");
  ctx_request("/do_throw");
  ctx_request("/dont_throw");
}

done_testing;

