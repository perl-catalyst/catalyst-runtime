use warnings;
use strict;
use Test::More;

# Test case for reported issue when an action consumes JSON but a
# POST sends nothing we get a hard error

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub test_forward :Local Args(0) {
    my( $self, $c ) = @_;
    my $view = $c->view('Test');
    $c->forward($view);

    Test::More::is("$view", "@{[ $c->res->body]}");
  }

  package MyApp::View::Test;
  $INC{'MyApp/View/Test.pm'} = __FILE__;

  use base 'Catalyst::View';

  sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    return ref($self)->new;
  }

  sub process {
    my ($self, $c, @args) = @_;
    $c->res->body("$self");
  }

  package MyApp;
  use Catalyst;
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

{
  ok my $res = request GET 'root/test_forward';
}

done_testing(2);
