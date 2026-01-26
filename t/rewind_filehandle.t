use warnings;
use strict;
use Test::More;

# Test case for reported issue when an action consumes JSON but a
# POST sends nothing we get a hard error

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub auto :Private {
      my ($self, $c) = @_;
      my $req_body = $c->req->body;
      if ($req_body) {
          $c->req->body->getline;
      }

      return 1; # continue dispatch
  }

  sub foo :Local Args(0) POST Consumes(JSON) {
      my ($self, $c) =@_;
      # try to access the deserialised JSON param via body_params
      my $name = $c->req->body_data->{name};
      $c->res->body("Hi, $name!");
  }

  package MyApp;
  use Catalyst;
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

{
  # Send POSTed JSON data to our handler that will read the body filehandle
  # via $req->body filehandle then call body_params (see GH PR #186)
  ok my $res = request POST 'root/foo',
    'Content-Type' => 'application/json',
    'Content' => '{"name": "Jack", "age": 42}';

  is $res->content, 'Hi, Jack!'; # don't say that on an aeroplane
}

done_testing();
