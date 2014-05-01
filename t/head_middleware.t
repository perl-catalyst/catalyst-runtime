use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use Plack::Test;

# Test to make sure we the order of some middleware is correct.  Basically
# we want to make sure that if the request is a HEAD we properly remove the
# body BUT not so quickly that we fail to calculate the length.  This test
# exists mainly to prevent regressions.

{  
  package MyApp::Controller::Root;

  use base 'Catalyst::Controller';

  sub test :Local {
    my ($self, $c) = @_;
    $c->response->body("This is the body");
  }

  package MyApp;
  use Catalyst;

  MyApp->setup;
}

$INC{'MyApp/Controller/Root.pm'} = __FILE__;

Test::More::ok(MyApp->setup);

ok my $psgi = MyApp->psgi_app, 'build psgi app';

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(GET "/root/test");
    is $res->code, 200, 'OK';
    is $res->content, 'This is the body', 'correct body';
    is $res->content_length, 16, 'correct length';
};

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(HEAD "/root/test");
    is $res->code, 200, 'OK';
    is $res->content, '', 'correct body';
    is $res->content_length, 16, 'correct length';    
};

done_testing;
