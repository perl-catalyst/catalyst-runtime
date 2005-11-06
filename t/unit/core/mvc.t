use Test::More tests => 7;
use strict;
use warnings;

use_ok('Catalyst');

my @complist =
  map { "MyApp::$_"; }
  qw/C::Controller M::Model V::View Controller::C Model::M View::V/;

{

    package MyApp;

    use base qw/Catalyst/;

    __PACKAGE__->components( { map { ( $_, $_ ) } @complist } );
}

is( MyApp->view('View'), 'MyApp::V::View', 'V::View ok' );

is( MyApp->controller('Controller'),
    'MyApp::C::Controller', 'C::Controller ok' );

is( MyApp->model('Model'), 'MyApp::M::Model', 'M::Model ok' );

is( MyApp->view('V'), 'MyApp::View::V', 'View::V ok' );

is( MyApp->controller('C'), 'MyApp::Controller::C', 'Controller::C ok' );

is( MyApp->model('M'), 'MyApp::Model::M', 'Model::M ok' );
