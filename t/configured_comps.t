use warnings;
use strict;
use HTTP::Request::Common;
use Test::More;

{
  package Local::Model::Foo;

  use Moose;
  extends 'Catalyst::Model';

  has a => (is=>'ro', required=>1);

  sub foo { shift->a . 'foo' }

  package Local::Controller::Errors;

  use Moose;
  use MooseX::MethodAttributes;

  extends 'Catalyst::Controller';

  has ['a', 'b'] => (is=>'ro', required=>1);

  sub not_found :Local { pop->res->from_psgi_response([404, [], ['Not Found']]) }

  package MyApp::Model::User;
  $INC{'MyApp/Model/User.pm'} = __FILE__;

  use Moose;
  extends 'Catalyst::Model';

  has 'zoo' => (is=>'ro', required=>1, isa=>'Object');

  around 'COMPONENT', sub {
    my ($orig, $class, $app, $config) = @_;
    $config->{zoo} = $app->model('Zoo');

    return $class->$orig($app, $config);
  };

  our %users = (
    1 => { name => 'john', age => 46 },
    2 => { name => 'mary', age => 36 },
    3 => { name => 'ian', age => 25 },
    4 => { name => 'visha', age => 18 },
  );

  sub find {
    my ($self, $id) = @_;
    my $user = $users{$id} || return;
    return bless $user, "MyApp::Model::User::user";
  }

  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;

  extends 'Catalyst::Controller';

  sub user :Local Args(1) {
    my ($self, $c, $int) = @_;
    
    Test::More::ok(my $user = $c->model("User")->find($int));
    Test::More::ok($c->model("User")->zoo->a);
    
    $c->res->body("name: $user->{name}, age: $user->{age}");
  }

  sub default :Default {
    my ($self, $c, $int) = @_;
    $c->res->body('default');
  }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  MyApp->config({
    'Controller::Err' => {
      from_component => 'Local::Controller::Errors',
      args => { a=> 100, b => 200, namespace =>'error' },
    },
    'Model::Zoo' => {
      from_component => 'Local::Model::Foo',
      args => { a=>2 },
    },
    'Model::Foo' => {
      from_component => 'Local::Model::Foo',
      args => { a=> 100 },
    },
  });

  MyApp->setup;
}

use Catalyst::Test 'MyApp';

{
  my $res = request '/user/1';
  is $res->content, 'name: john, age: 46';
}

{
  my $res = request '/error/not_found';
  is $res->content, 'Not Found';
}

done_testing;
