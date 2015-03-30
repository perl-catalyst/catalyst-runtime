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
  use MyApp::Types qw/Tuple Int Str StrMatch ArrayRef Enum UserId  Heart/;

  extends 'Catalyst::Controller';

  sub user :Local Args(1)
   Query(page=>Int,user=>Tuple[Enum['a','b'],Int]) {
    my ($self, $c, $int) = @_;
    $c->res->body("page ${\$c->req->query_parameters->{page}}, user ${\$c->req->query_parameters->{user}[1]}");
  }

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

done_testing;
