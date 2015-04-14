use strict;
use warnings; 
use Test::More;
use Catalyst::Utils;
use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
package Model::Banana;
 
use base qw/Catalyst::Model/;
 
package TestCatalyst; $INC{'TestCatalyst.pm'} = 1;
 
use Catalyst::Runtime '5.70';
 
use Moose;
BEGIN { extends qw/Catalyst/ }
 
use Catalyst;
 
after 'setup_components' => sub {
    my $self = shift;
    Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Model::Banana' );
    Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Test::Apple' );
    Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Model::Banana', as => 'Cherry' );
    Catalyst::Utils::inject_component( into => __PACKAGE__, component => 'Test::Apple', as => 'Apple' );
};
 
TestCatalyst->config( 'home' => '.' );
 
TestCatalyst->setup;
 
}
 
package main;
 
use Catalyst::Test qw/TestCatalyst/;
 
ok( TestCatalyst->controller( $_ ) ) for qw/ Apple Test::Apple /;
ok( TestCatalyst->model( $_ ) ) for qw/ Banana Cherry /;

done_testing;
