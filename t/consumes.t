use warnings;
use strict;
use Test::More;

# Test case for reported issue when an action consumes JSON but a
# POST sends nothing we get a hard error

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub bar :Local Args(0) POST Consumes(JSON) {
    my( $self, $c ) = @_;
    my $foo = $c->req->body_data;
  }

  sub end :Private {
    my( $self, $c ) = @_;
    my $body = $c->shift_errors;
    $c->res->body( $body || "No errors");
  }

  package MyApp;
  use Catalyst;
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

{
  # Test to send no post
  ok my $res = request POST 'root/bar',
    'Content-Type' => 'application/json';

  like $res->content, qr"Error Parsing POST 'undef'";
}

{
  # Test to send bad (malformed JSON) post
  ok my $res = request POST 'root/bar',
    'Content-Type' => 'application/json',
    'Content' => 'i am not JSON';

  like $res->content, qr/Error Parsing POST 'i am not JSON'/;
}

{
  # Test to send bad (malformed JSON) post
  ok my $res = request POST 'root/bar',
    'Content-Type' => 'application/json',
    'Content' => '{ "a":"b" }';

  is $res->content, 'No errors';
}

done_testing();
