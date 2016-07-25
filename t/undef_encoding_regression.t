use utf8;
use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use HTTP::Message::PSGI ();
use Encode 2.21 'decode_utf8', 'encode_utf8', 'encode';

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub heart :Local Args(1) {
    my ($self, $c, $arg) = @_;

    Test::More::is $c->req->query_parameters->{a}, 111;
    Test::More::is $c->req->query_parameters->{b}, 222;
    Test::More::is $arg, 1;

    $c->response->content_type('text/html');
    $c->response->body("<p>This is path local</p>");
  }

  package MyApp;
  use Catalyst;

  MyApp->config(encoding => undef);

  Test::More::ok(MyApp->setup, 'setup app');
}

use Catalyst::Test 'MyApp';

{
  my $res = request "/root/heart/1?a=111&b=222";
  is $res->code, 200, 'OK';
  is $res->content, '<p>This is path local</p>';
}

done_testing;
