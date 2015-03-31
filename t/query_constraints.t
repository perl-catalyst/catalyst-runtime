use warnings;
use strict;
use HTTP::Request::Common;
use utf8;

BEGIN {
  use Test::More;
  eval "use Type::Tiny 1.000005; 1" || do {
    plan skip_all => "Trouble loading Type::Tiny and friends => $@";
  };
}

BEGIN {
  package MyApp::Types;
  $INC{'MyApp/Types.pm'} = __FILE__;

  use strict;
  use warnings;
 
  use Type::Utils -all;
  use Types::Standard -types;
  use Type::Library
   -base,
   -declare => qw( UserId Heart );

  extends "Types::Standard"; 

  declare UserId,
   as Int,
   where { $_ < 5 };

  declare Heart,
   as Str,
   where { $_ eq '♥' };

}

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;
  use Types::Standard 'slurpy';
  use MyApp::Types qw/Dict Tuple Int StrMatch HashRef ArrayRef Enum UserId  Heart/;

  extends 'Catalyst::Controller';

  sub user :Local Args(1)
   Query(page=>Int,user=>Tuple[Enum['a','b'],Int]) {
    my ($self, $c, $int) = @_;
    $c->res->body("page ${\$c->req->query_parameters->{page}}, user ${\$c->req->query_parameters->{user}[1]}");
  }

  sub user_slurps :Local Args(1)
   Query(page=>Int,user=>Tuple[Enum['a','b'],Int],...) {
    my ($self, $c, $int) = @_;
    $c->res->body("page ${\$c->req->query_parameters->{page}}, user ${\$c->req->query_parameters->{user}[1]}");
  }

  sub string_types :Local Query(q=>'Str',age=>'Int') { pop->res->body('string_type') }
 
  sub as_ref :Local Query(Dict[age=>Int,sex=>Enum['f','m','o'], slurpy HashRef[Int]]) { pop->res->body('as_ref') }

  sub utf8 :Local Query(utf8=>Heart) { pop->res->body("heart") }

  sub chain :Chained(/) CaptureArgs(0) Query(age=>Int,...) { }

    sub big :Chained(chain) PathPart('') Args(0) Query(size=>Int,...) { pop->res->body('big') }
    sub small :Chained(chain) PathPart('') Args(0) Query(size=>UserId,...) { pop->res->body('small') }
  
  sub default :Default {
    my ($self, $c, $int) = @_;
    $c->res->body('default');
  }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  MyApp->setup;
}

use Catalyst::Test 'MyApp';

{
  my $res = request '/user/1?page=10&user=a&user=100';
  is $res->content, 'page 10, user 100';
}

{
  my $res = request '/user/1?page=10&user=d&user=100';
  is $res->content, 'default';
}

{
  my $res = request '/user/1?page=string&user=a&user=100';
  is $res->content, 'default';
}

{
  my $res = request '/user/1?page=10&user=a&user=100&foo=bar';
  is $res->content, 'default';
}

{
  my $res = request '/user/1?page=10&user=a&user=100&user=bar';
  is $res->content, 'default';
}

{
  my $res = request '/user_slurps/1?page=10&user=a&user=100&foo=bar';
  is $res->content, 'page 10, user 100';
}

{
  my $res = request '/string_types?q=sssss&age=10';
  is $res->content, 'string_type';
}

{
  my $res = request '/string_types?w=sssss&age=10';
  is $res->content, 'default';
}

{
  my $res = request '/string_types?q=sssss&age=string';
  is $res->content, 'default';
}

{
  my $res = request '/as_ref?q=sssss&age=string';
  is $res->content, 'default';
}

{
  my $res = request '/as_ref?age=10&sex=o&foo=bar&baz=bot';
  is $res->content, 'default';
}

{
  my $res = request '/as_ref?age=10&sex=o&foo=122&baz=300';
  is $res->content, 'as_ref';
}

{
  my $res = request '/utf8?utf8=♥';
  is $res->content, 'heart';
}

{
  my $res = request '/chain?age=string&size=2';
  is $res->content, 'default';
}

{
  my $res = request '/chain?age=string&size=string';
  is $res->content, 'default';
}

{
  my $res = request '/chain?age=50&size=string';
  is $res->content, 'default';
}

{
  my $res = request '/chain?age=10&size=100';
  is $res->content, 'big';
}

{
  my $res = request '/chain?age=10&size=2';
  is $res->content, 'small';
}

done_testing;
