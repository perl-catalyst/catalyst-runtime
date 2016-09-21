use warnings;
use strict;
use Test::More;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub root :Path('') Args(0) {
    my ($self, $c) = @_;
    $c->{stash}->{foo} = 'bar';
    $c->stash(baz=>'boor');
    $c->{stash}->{baz} = $c->stash->{baz} . 2;
    
    Test::More::is($c->stash->{foo}, 'bar');
    Test::More::is($c->stash->{baz}, 'boor2');
    Test::More::is($c->{stash}->{foo}, 'bar');
    Test::More::is($c->{stash}->{baz}, 'boor2');

    $c->res->body('return');
  }

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
