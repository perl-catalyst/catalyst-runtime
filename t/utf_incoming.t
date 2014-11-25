use utf8;
use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

# Test cases for incoming utf8 

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub heart :Path('♥') {
    my ($self, $c) = @_;
    $c->response->content_type('text/html');
    $c->response->body("<p>This is path-heart action ♥</p>");
    # We let the content length middleware find the length...
  }

  sub hat :Path('^') {
    my ($self, $c) = @_;
    $c->response->content_type('text/html');
    $c->response->body("<p>This is path-hat action ^</p>");
  }

  sub uri_for :Path('uri_for') {
    my ($self, $c) = @_;
    $c->response->content_type('text/html');
    $c->response->body("${\$c->uri_for($c->controller('Root')->action_for('argend'), ['♥'], '♥', {'♥'=>'♥♥'})}");
  }

  sub heart_with_arg :Path('a♥') Args(1)  {
    my ($self, $c, $arg) = @_;
    $c->response->content_type('text/html');
    $c->response->body("<p>This is path-heart-arg action $arg</p>");
    Test::More::is $c->req->args->[0], '♥';
  }

  sub base :Chained('/') CaptureArgs(0) { }
    sub link :Chained('base') PathPart('♥') Args(0) {
      my ($self, $c) = @_;
      $c->response->content_type('text/html');
      $c->response->body("<p>This is base-link action ♥</p>");
    }
    sub arg :Chained('base') PathPart('♥') Args(1) {
      my ($self, $c, $arg) = @_;
      $c->response->content_type('text/html');
      $c->response->body("<p>This is base-link action ♥ $arg</p>");
    }
    sub capture :Chained('base') PathPart('♥') CaptureArgs(1) {
      my ($self, $c, $arg) = @_;
      $c->stash(capture=>$arg);
    }
      sub argend :Chained('capture') PathPart('♥') Args(1) {
        my ($self, $c, $arg) = @_;
        $c->response->content_type('text/html');

        Test::More::is $c->req->args->[0], '♥';
        Test::More::is $c->req->captures->[0], '♥';

        $c->response->body("<p>This is base-link action ♥ ${\$c->req->args->[0]}</p>");
      }

  package MyApp;
  use Catalyst;

  MyApp->config(encoding=>'UTF-8');

  Test::More::ok(MyApp->setup, 'setup app');
}

ok my $psgi = MyApp->psgi_app, 'build psgi app';

use Catalyst::Test 'MyApp';
use Encode 2.21 'decode_utf8', 'encode_utf8';

{
  my $res = request "/root/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-heart action ♥</p>', 'correct body';
  is $res->content_length, 36, 'correct length';
}

{
  my $res = request "/root/a♥/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-heart-arg action ♥</p>', 'correct body';
  is $res->content_length, 40, 'correct length';
}

{
  my $res = request "/root/^";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-hat action ^</p>', 'correct body';
  is $res->content_length, 32, 'correct length';
}

{
  my $res = request "/base/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
}

{
  my ($res, $c) = ctx_request POST "/base/♥?♥=♥&♥=♥♥", [a=>1, b=>'', '♥'=>'♥', '♥'=>'♥♥'];

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
  is $c->req->parameters->{'♥'}[0], '♥';
  is $c->req->query_parameters->{'♥'}[0], '♥';
  is $c->req->body_parameters->{'♥'}[0], '♥';
  is $c->req->parameters->{'♥'}[0], '♥';
  is $c->req->parameters->{a}, 1;
  is $c->req->body_parameters->{a}, 1;
}

{
  my ($res, $c) = ctx_request GET "/base/♥?♥♥♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
  is $c->req->query_keywords, '♥♥♥';
}

{
  my $res = request "/base/♥/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥ ♥</p>', 'correct body';
  is $res->content_length, 39, 'correct length';
}

{
  my $res = request "/base/♥/♥/♥/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥ ♥</p>', 'correct body';
  is $res->content_length, 39, 'correct length';
}

{
  my ($res, $c) = ctx_request POST "/base/♥/♥/♥/♥?♥=♥♥", [a=>1, b=>'2', '♥'=>'♥♥'];

  ## Make sure that the urls we generate work the same
  my $uri_for = $c->uri_for($c->controller('Root')->action_for('argend'), ['♥'], '♥', {'♥'=>'♥♥'});
  my $uri = $c->req->uri;

  is "$uri", "$uri_for";

  {
    my ($res, $c) = ctx_request POST "$uri_for", [a=>1, b=>'2', '♥'=>'♥♥'];
    is $c->req->query_parameters->{'♥'}, '♥♥';
    is $c->req->body_parameters->{'♥'}, '♥♥';
    is $c->req->parameters->{'♥'}[0], '♥♥'; #combined with query and body
  }
}

{
  my ($res, $c) = ctx_request "/root/uri_for";
  my $url = $c->uri_for($c->controller('Root')->action_for('argend'), ['♥'], '♥', {'♥'=>'♥♥'});

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), "$url", 'correct body'; #should do nothing
  is $res->content, "$url", 'correct body';
  is $res->content_length, 90, 'correct length';
}

done_testing;
