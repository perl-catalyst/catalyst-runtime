use utf8;
use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use Encode 2.21 'decode_utf8', 'encode_utf8';
use File::Spec;

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

        # Test to make sure redirect can now take an object (sorry don't have a better place for it
        # but wanted test coverage.
        my $location = $c->res->redirect( $c->uri_for($c->controller('Root')->action_for('uri_for')) );
        Test::More::ok !ref $location; 
      }

  sub stream_write :Local {
    my ($self, $c) = @_;
    $c->response->content_type('text/html');
    $c->response->write("<p>This is stream_write action ♥</p>");
  }

  sub stream_write_fh :Local {
    my ($self, $c) = @_;
    $c->response->content_type('text/html');

    my $writer = $c->res->write_fh;
    $writer->write_encoded('<p>This is stream_write_fh action ♥</p>');
    $writer->close;
  }

  # Stream a file with utf8 chars directly, you don't need to decode
  sub stream_body_fh :Local {
    my ($self, $c) = @_;
    my $path = File::Spec->catfile('t', 'utf8.txt');
    open(my $fh, '<', $path) || die "trouble: $!";
    $c->response->content_type('text/html');
    $c->response->body($fh);
  }

  # If you pull the file contents into a var, NOW you need to specify the
  # IO encoding on the FH.  Ultimately Plack at the end wants bytes...
  sub stream_body_fh2 :Local {
    my ($self, $c) = @_;
    my $path = File::Spec->catfile('t', 'utf8.txt');
    open(my $fh, '<:encoding(UTF-8)', $path) || die "trouble: $!";
    my $contents = do { local $/; <$fh> };

    $c->response->content_type('text/html');
    $c->response->body($contents);
  }


  package MyApp;
  use Catalyst;

  # Default encoding is now UTF-8
  # MyApp->config(encoding=>'UTF-8');

  Test::More::ok(MyApp->setup, 'setup app');
}

ok my $psgi = MyApp->psgi_app, 'build psgi app';

use Catalyst::Test 'MyApp';

{
  my $res = request "/root/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-heart action ♥</p>', 'correct body';
  is $res->content_length, 36, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/root/a♥/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-heart-arg action ♥</p>', 'correct body';
  is $res->content_length, 40, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/root/^";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is path-hat action ^</p>', 'correct body';
  is $res->content_length, 32, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/base/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
  is $res->content_charset, 'UTF-8';
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
  is $res->content_charset, 'UTF-8';
}

{
  my ($res, $c) = ctx_request GET "/base/♥?♥♥♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥</p>', 'correct body';
  is $res->content_length, 35, 'correct length';
  is $c->req->query_keywords, '♥♥♥';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/base/♥/♥";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is base-link action ♥ ♥</p>', 'correct body';
  is $res->content_length, 39, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/base/♥/♥/♥/♥";

  is decode_utf8($res->content), '<p>This is base-link action ♥ ♥</p>', 'correct body';
  is $res->content_length, 39, 'correct length';
  is $res->content_charset, 'UTF-8';
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
    is $res->content_charset, 'UTF-8';
  }
}

{
  my ($res, $c) = ctx_request "/root/uri_for";
  my $url = $c->uri_for($c->controller('Root')->action_for('argend'), ['♥'], '♥', {'♥'=>'♥♥'});

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), "$url", 'correct body'; #should do nothing
  is $res->content, "$url", 'correct body';
  is $res->content_length, 90, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/root/stream_write";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is stream_write action ♥</p>', 'correct body';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/root/stream_body_fh";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), "<p>This is stream_body_fh action ♥</p>\n", 'correct body';
  is $res->content_charset, 'UTF-8';
  # Not sure why there is a trailing newline above... its not in catalyst code I can see. Not sure
  # if is a problem or just an artifact of the why the test stuff works - JNAP
}

{
  my $res = request "/root/stream_write_fh";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), '<p>This is stream_write_fh action ♥</p>', 'correct body';
  #is $res->content_length, 41, 'correct length';
  is $res->content_charset, 'UTF-8';
}

{
  my $res = request "/root/stream_body_fh2";

  is $res->code, 200, 'OK';
  is decode_utf8($res->content), "<p>This is stream_body_fh action ♥</p>\n", 'correct body';
  is $res->content_length, 41, 'correct length';
  is $res->content_charset, 'UTF-8';
}

done_testing;
