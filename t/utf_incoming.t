use utf8;
use warnings;
use strict;

use Test::More;
use HTTP::Request::Common;
use Plack::Test;

# Test cases for incoming utf8 

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub heart :Path('♥') {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
  }

  sub hat :Path('^') {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
  }

  sub base :Chained('/') CaptureArgs(0) { }
    sub link :Chained('base') PathPart('♥') Args(0) {
      my ($self, $c) = @_;
      $c->response->body("This is the body");
    }

  package MyApp;
  use Catalyst;

  Test::More::ok(MyApp->setup, 'setup app');
}

ok my $psgi = MyApp->psgi_app, 'build psgi app';

test_psgi $psgi, sub {
    my $cb = shift;
    #my $res = $cb->(GET "/root/test");
    #is $res->code, 200, 'OK';
    #is $res->content, 'This is the body', 'correct body';
    #is $res->content_length, 16, 'correct length';
};

done_testing;
