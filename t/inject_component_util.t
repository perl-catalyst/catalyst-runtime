use strict;
use warnings; 
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
  package RoleTest1;
  use Moose::Role;

  sub aaa { 'aaa' }

 $INC{'RoleTest1.pm'} = __FILE__;

  package RoleTest2;
  use Moose::Role;

  sub bbb { 'bbb' }

 $INC{'RoleTest2.pm'} = __FILE__;

  package Model::Banana;
  use base qw/Catalyst::Model/;

 $INC{'Model/Banana.pm'} = __FILE__;

  package Model::BananaMoose;

  use Moose;
  extends 'Catalyst::Model';

  Model::BananaMoose->meta->make_immutable;
 $INC{'Model/BananaMoose.pm'} = __FILE__;
}

{
  package TestCatalyst;
  $INC{'TestCatalyst.pm'} = __FILE__;
   
  use Moose;
  use Catalyst;
  use Catalyst::Utils;
   
  after 'setup_components' => sub {
      my $self = shift;
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Model::Banana' );
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Test::Apple' );
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Model::Banana', as => 'Cherry' );
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Model::BananaMoose', as => 'CherryMoose', traits => ['RoleTest1', 'RoleTest2'] );
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Test::Apple', as => 'Apple' );
      Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Test::Apple', as => 'Apple2', traits => ['RoleTest1', 'RoleTest2'] );
  };
   
  TestCatalyst->config( 'home' => '.' ); 
  TestCatalyst->setup;
}
 
use Catalyst::Test qw/TestCatalyst/;
 
ok( TestCatalyst->controller( $_ ) ) for qw/ Apple Test::Apple /;
ok( TestCatalyst->model( $_ ) ) for qw/ Banana Cherry /;
is( TestCatalyst->controller('Apple2')->aaa, 'aaa');
is( TestCatalyst->controller('Apple2')->bbb, 'bbb');
is( TestCatalyst->model('CherryMoose')->aaa, 'aaa');
is( TestCatalyst->model('CherryMoose')->bbb, 'bbb');

done_testing;
