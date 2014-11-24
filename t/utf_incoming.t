use utf8;
use warnings;
use strict;
use Test::More;

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

  sub base :Chained('/') CaptureArgs(0) { }
    sub link :Chained('base') PathPart('♥') Args(0) {
      my ($self, $c) = @_;
      $c->response->content_type('text/html');
      $c->response->body("<p>This is base-link action ♥</p>");
    }

  package MyApp;
  use Catalyst;

  MyApp->config(encoding=>'UTF-8');

  Test::More::ok(MyApp->setup, 'setup app');
}

ok my $psgi = MyApp->psgi_app, 'build psgi app';

use Catalyst::Test 'MyApp';
use Encode 2.21 'decode_utf8';

{
  my $res = request "/root/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-heart action ♥</p>', 'correct body';
  is $res->content_length, 36, 'correct length';
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
  my $res = request "/base/♥?♥=♥♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
}


done_testing;
