use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;

  extends 'Catalyst::Controller';

  sub an_int :Local Args(Int) {
    my ($self, $c, $int) = @_;
    #use Devel::Dwarn; Dwarn $self;
    $c->res->body('an_int');
  }

    # For Args(N) Args(T) Args Args(T) Args(N)
    sub nttn :Local Args(2) Args(Int) Args(Int) Args Args(3) Args(Int) Args(1) {
    my ($self, $c, $int) = @_;
    #use Devel::Dwarn; Dwarn $self;
    $c->res->body('nttn');
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
  my $res = request '/an_int/1';
  is $res->content, 'an_int';
}

{
  my $res = request '/an_int/aa';
  is $res->content, 'default';
}

{
                          # Args(2)  Int Int Args  Args(3) Int Args(1)
  my $res = request '/nttn/aaaa/bbbb/123/567/*/**/cc/dd/ee/890/fffffff';
  is $res->content, 'nttn';

     $res = request '/nttn/aaaa/bbbb/123/567/cc/dd/ee/890/fffffff';
  is $res->content, 'nttn';
}

{
  my $res = request '/nttn/aaaa/bbbb/XXX/567/*/**/cc/dd/ee/890/fffffff';
  is $res->content, 'default';

     $res = request '/nttn/aaaa/bbbb/123/XXX/*/**/cc/dd/ee/890/fffffff';
  is $res->content, 'default';

     $res = request '/nttn/aaaa/bbbb/123/456/*/**/cc/dd/ee/XXX/fffffff';
  is $res->content, 'default';
}

done_testing;
