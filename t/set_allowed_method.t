use warnings;
use strict;
use Test::More;

# Test case for reported issue when an action consumes JSON but a
# POST sends nothing we get a hard error

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub root :Chained(/) CaptureArgs(0) { }

    sub get :GET Chained(root) PathPart('') Args(0) { }
    sub post :POST Chained(root) PathPart('') Args(0) { }
    sub put :PUT Chained(root) PathPart('') Args(0) { }

  package MyApp;
  use Catalyst;
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

{
   ok my $res = request POST 'root/';
}

done_testing();
