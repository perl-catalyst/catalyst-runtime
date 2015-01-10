use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;

  extends 'Catalyst::Controller';

  sub check :Local {
    pop->res->from_psgi_response([200, ['Content-Type'=>'text/plain'],['check']]);
  }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  MyApp->setup;
}

use Catalyst::Test 'MyApp';

{
  my $res = request '/check';
  is $res->code, 200, 'OK';
  is $res->content, 'check', 'correct body';
  is $res->content_length, 5, 'correct length';
}

done_testing;
