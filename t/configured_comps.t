use warnings;
use strict;
use HTTP::Request::Common;
use Test::More;

{
  package TestRole;

  use Moose::Role;

  sub role { 'role' }
  
  package Local::Model::Foo;

  use Moose;
  extends 'Catalyst::Model';

  has a => (is=>'ro', required=>1);
  has b => (is=>'ro');

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
    Test::More::is($c->model("User")->zoo->a, 2);
    Test::More::is($c->model("Foo")->role, 'role');
    Test::More::is($c->model("One")->a, 'one');
    Test::More::is($c->model("Two")->a, 'two');
   
    $c->res->body("name: $user->{name}, age: $user->{age}");
  }

  sub default :Default {
    my ($self, $c, $int) = @_;
    $c->res->body('default');
  }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  MyApp->inject_components(
      'Model::One' => { from_component => 'Local::Model::Foo' },
      'Model::Two' => { from_component => 'Local::Model::Foo' },
  );

  MyApp->config({
    inject_components => {
      'Controller::Err' => { from_component => 'Local::Controller::Errors' },
      'Model::Zoo' => { from_component => 'Local::Model::Foo' },
      'Model::Foo' => { from_component => 'Local::Model::Foo', roles => ['TestRole'] },
    },
    'Controller::Err' => { a => 100, b => 200, namespace => 'error' },
    'Model::Zoo' => { a => 2 },
    'Model::Foo' => { a => 100 },
    'Model::One' => { a => 'one' },
    'Model::Two' => { a => 'two' },

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
