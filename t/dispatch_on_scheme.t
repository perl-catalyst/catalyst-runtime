use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

# Test cases for dispatching on URI Scheme

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub is_http :Path(scheme) Scheme(http) Args(0) {
    my ($self, $c) = @_;
    Test::More::is $c->action->scheme, 'http';
    $c->response->body("is_http");
  }

  sub is_https :Path(scheme) Scheme(https) Args(0)  {
    my ($self, $c) = @_;
    Test::More::is $c->action->scheme, 'https';
    $c->response->body("is_https");
  }

  sub base :Chained('/') CaptureArgs(0) { }

    sub is_http_chain :GET Chained('base') PathPart(scheme) Scheme(http) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'http';
      $c->response->body("base/is_http");
    }

    sub is_https_chain :Chained('base') PathPart(scheme) Scheme(https) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'https';
      $c->response->body("base/is_https");
    }

    sub uri_for1 :Chained('base') Scheme(https) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'https';
      $c->response->body($c->uri_for($c->action)->as_string);
    }

    sub uri_for2 :Chained('base') Scheme(https) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'https';
      $c->response->body($c->uri_for($self->action_for('is_http'))->as_string);
    }

    sub uri_for3 :Chained('base') Scheme(http) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'http';
      $c->response->body($c->uri_for($self->action_for('endpoint'))->as_string);
    }

  sub base2 :Chained('/') CaptureArgs(0) { }
    sub link :Chained(base2) Scheme(https) CaptureArgs(0) { }
      sub endpoint :Chained(link) Args(0) {
        my ($self, $c) = @_;
        Test::More::is $c->action->scheme, 'https';
        $c->response->body("end");
      }


  package MyApp;
  use Catalyst;

  Test::More::ok(MyApp->setup, 'setup app');
}

use Catalyst::Test 'MyApp';

{
  my $res = request "/root/scheme";
  is $res->code, 200, 'OK';
  is $res->content, 'is_http', 'correct body';
}

{
  my $res = request "https://localhost/root/scheme";
  is $res->code, 200, 'OK';
  is $res->content, 'is_https', 'correct body';
}

{
  my $res = request "/base/scheme";
  is $res->code, 200, 'OK';
  is $res->content, 'base/is_http', 'correct body';
}

{
  my $res = request "https://localhost/base/scheme";
  is $res->code, 200, 'OK';
  is $res->content, 'base/is_https', 'correct body';
}

{
  my $res = request "https://localhost/base/uri_for1";
  is $res->code, 200, 'OK';
  is $res->content, 'https://localhost/base/uri_for1', 'correct body';
}

{
  my $res = request "https://localhost/base/uri_for2";
  is $res->code, 200, 'OK';
  is $res->content, 'http://localhost/root/scheme', 'correct body';
}

{
  my $res = request "/base/uri_for3";
  is $res->code, 200, 'OK';
  is $res->content, 'https://localhost/base2/link/endpoint', 'correct body';
}

{
  my $res = request "https://localhost/base2/link/endpoint";
  is $res->code, 200, 'OK';
  is $res->content, 'end', 'correct body';
}

done_testing;
