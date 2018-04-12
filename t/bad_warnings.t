use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

# In DEBUG mode, we get not a number warnigs

my $error;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub root :Chained(/) PathPrefix CaptureArgs(0) { }

  sub test :Chained(root) Args('"Int"') {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
  }

  sub infinity :Chained(root) PathPart('test') Args {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
    Test::More::is $c->action->comparable_arg_number, ~0;
  }

  sub midpoint :Chained(root) PathPart('') CaptureArgs('"Int"') {
    my ($self, $c) = @_;
    Test::More::is $c->action->number_of_captures, 1;
    #Test::More::is $c->action->number_of_captures_constraints, 1;
  }

  sub endpoint :Chained('midpoint') Args('"Int"') {
    my ($self, $c) = @_;
    Test::More::is $c->action->comparable_arg_number, 1;
    Test::More::is $c->action->normalized_arg_number, 1;
  }

  sub local :Local Args {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
    Test::More::is $c->action->comparable_arg_number, ~0;
  }


  package MyApp;
  use Catalyst;

  sub debug { 1 }

  $SIG{__WARN__} = sub { $error = shift };

  MyApp->setup;
}

use Catalyst::Test 'MyApp';

request GET '/root/test/a/b/c';
request GET '/root/local/a/b/c';
request GET '/root/11/endpoint/22';


if($error) {
  unlike($error, qr[Argument ""Int"" isn't numeric in repeat]);
} else {
  ok 1;
}

done_testing(6);
