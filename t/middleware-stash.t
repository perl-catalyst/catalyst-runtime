use warnings;
use strict;

{

  package MyAppChild::Controller::User;
  $INC{'MyAppChild/Controller/User.pm'} = __FILE__;

  use base 'Catalyst::Controller';
  use Test::More;

  sub stash :Local {
    my ($self, $c) = @_;
    $c->stash->{inner} = "inner";
    $c->res->body( "inner: ${\$c->stash->{inner}}, outer: ${\$c->stash->{outer}}");

    is_deeply [sort {$a cmp $b} keys(%{$c->stash})], ['inner','outer'], 'both keys in stash';
  }

  package MyAppChild;
  $INC{'MyAppChild.pm'} = __FILE__;

  use Catalyst;
  MyAppChild->setup;

  package MyAppParent::Controller::User;
  $INC{'MyAppParent/Controller/User.pm'} = __FILE__;

  use base 'Catalyst::Controller';
  use Test::More;

  sub stash :Local {
    my ($self, $c) = @_;
    $c->stash->{outer} = "outer";
    $c->res->from_psgi_response( MyAppChild->to_app->($c->req->env) );

    is_deeply [keys(%{$c->stash})], ['outer'], 'only one key in stash';
  }

  package MyAppParent;
  use Catalyst;
  MyAppParent->setup;

}

use Test::More;
use Catalyst::Test 'MyAppParent';

my $res = request '/user/stash';
is $res->content, 'inner: inner, outer: outer', 'got expected response';

done_testing;
