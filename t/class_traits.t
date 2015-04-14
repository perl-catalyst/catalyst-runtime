use strict;
use warnings;
use Test::More;
use Class::MOP;

BEGIN {
  package TestRole;
  use Moose::Role;

  sub a { 'a' }
  sub b { 'b' }
}
 
{
  package TestApp;
 
  use Catalyst;

  __PACKAGE__->request_class_traits([qw/TestRole/]);
  __PACKAGE__->response_class_traits([qw/TestRole/]);
  __PACKAGE__->stats_class_traits([qw/TestRole/]);

  __PACKAGE__->setup;
}
 
 
foreach my $class_prefix (qw/request response stats/) {
  my $method = 'composed_' .$class_prefix. '_class';
  ok(
    Class::MOP::class_of(TestApp->$method)->does_role('TestRole'),
    "$method does TestRole",
  );
}

use Catalyst::Test 'TestApp';

my ($res, $c) = ctx_request '/';

is $c->req->a, 'a';
is $c->req->b, 'b';
is $c->res->a, 'a';
is $c->res->b, 'b';

done_testing;
