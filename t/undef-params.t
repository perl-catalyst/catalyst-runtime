use warnings;
use strict ;
use Test::More;
use HTTP::Request::Common;
use Plack::Test;

# If someone does $c->req->params(undef) you don't get a very good
# error message.  This is a test to see if the proposed change improves
# that.


{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub test :Local {
    my ($self, $c) = @_;
    my $value = $c->req->param(undef);

    $c->response->body("This is the body");
  }

  sub set_params :Local {
    my ($self, $c) = @_;
    $c->req->param(foo => 'a', 'b', 'c');
    $c->res->body(join ',', $c->req->param('foo'));
  }

  package MyApp;
  use Catalyst;

  $SIG{__WARN__} = sub {
    my $error = shift;
    Test::More::is($error, "You called ->params with an undefined value at t/undef-params.t line 20.\n")
      unless MyApp->debug;
  };

  MyApp->setup, 'setup app';
}

ok my $psgi = MyApp->psgi_app, 'build psgi app';

test_psgi $psgi, sub {
    my $cb = shift;

    {
      my $res = $cb->(GET "/root/test");
      is $res->code, 200, 'OK';
    }

    {
      my $res = $cb->(GET "/root/set_params");
      is $res->code, 200, 'OK';
      is $res->content, 'a,b,c';
    }
};

done_testing;
