use warnings;
use strict;

# For reported: https://rt.cpan.org/Ticket/Display.html?id=97948

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub example :Local Args(0) {
    pop->stash->{testing1} = 'testing2';
  }

  package MyApp;
  use Catalyst;

  MyApp->setup;
}

use Test::More;
use Catalyst::Test 'MyApp';

my ($res, $c) = ctx_request('/root/example');
is $c->stash->{testing1}, 'testing2', 'got expected stash value';

done_testing;
