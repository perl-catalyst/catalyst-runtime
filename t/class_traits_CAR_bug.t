use strict;
use warnings;
use Test::More;
use Class::MOP;

BEGIN {
  use Test::More;
  eval "use Catalyst::Action::REST; 1" || do {
    plan skip_all => "Trouble loading Catalyst::Action::REST => $@";
  };
}

BEGIN {
  my %hidden = map { (my $m = "$_.pm") =~ s{::}{/}g; $m => 1 } qw(
    Foo
    Bar
  );
  unshift @INC, sub {
    return unless exists $hidden{$_[1]};
    die "Can't locate $_[1] in \@INC (hidden)\n";
  };
}

BEGIN {
  package TestRole;
  $INC{'TestRole'} = __FILE__;
  use Moose::Role;

  sub a { 'a' }
  sub b { 'b' }

  package Catalyst::TraitFor::Request::Foo;
  $INC{'Catalyst/TraitFor/Request/Foo.pm'} = __FILE__;
  use Moose::Role;

  sub c { 'c' }

  package TestApp::TraitFor::Request::Bar;
  $INC{'TestApp/TraitFor/Request/Bar.pm'} = __FILE__;
  use Moose::Role;

  sub d { 'd' }

  package TestApp::Controller::Root;
  $INC{'TestApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;


}
 
{
  package TestApp;
  $INC{'TestApp.pm'} = __FILE__;
 
  use Catalyst;

  __PACKAGE__->request_class_traits([qw/TestRole Foo Bar/]);
  __PACKAGE__->setup;
}
 
 
foreach my $class_prefix (qw/request/) {
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
is $c->req->c, 'c';
is $c->req->d, 'd';

done_testing;
