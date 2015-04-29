use strict;
use warnings;
use Test::More;

{
  package MyApp::Model::AcceptContext;
  use base 'Catalyst::Model';

  sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    Test::More::ok( ref $c);
  }

  $INC{'MyApp/Model/AcceptContext.pm'} = __FILE__;

  package MyApp::Controller::Root;
  use base 'Catalyst::Controller';

  sub test_model :Local {
    my ($self, $c) = @_;
    $c->res->body('test');
  }

  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  package MyApp;
  use Catalyst;
  
  MyApp->setup;
}

use Catalyst::Test 'MyApp';

my ($res, $c) = ctx_request('/test_model');

ok $res;


done_testing;

