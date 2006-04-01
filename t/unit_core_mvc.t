use Test::More tests => 13;
use strict;
use warnings;

use_ok('Catalyst');

my @complist =
  map { "MyApp::$_"; }
  qw/C::Controller M::Model V::View Controller::C Model::M View::V Controller::Model::Dummy::Model Model::Dummy::Model/;

my $thingie={};
bless $thingie,'MyApp::Model::Test::Object';
push @complist,$thingie;
{

    package MyApp;

    use base qw/Catalyst/;

    __PACKAGE__->components( { map { ( ref($_)||$_ , $_ ) } @complist } );
}

is( MyApp->view('View'), 'MyApp::V::View', 'V::View ok' );

is( MyApp->controller('Controller'),
    'MyApp::C::Controller', 'C::Controller ok' );

is( MyApp->model('Model'), 'MyApp::M::Model', 'M::Model ok' );

is( MyApp->model('Dummy::Model'), 'MyApp::Model::Dummy::Model', 'Model::Dummy::Model ok' );

isa_ok( MyApp->model('Test::Object'), 'MyApp::Model::Test::Object', 'Test::Object ok' );

is( MyApp->controller('Model::Dummy::Model'), 'MyApp::Controller::Model::Dummy::Model', 'Controller::Model::Dummy::Model ok' );

is( MyApp->view('V'), 'MyApp::View::V', 'View::V ok' );

is( MyApp->controller('C'), 'MyApp::Controller::C', 'Controller::C ok' );

is( MyApp->model('M'), 'MyApp::Model::M', 'Model::M ok' );

is_deeply( [ sort MyApp->views ],
           [ qw/V View/ ],
           'views ok' );

is_deeply( [ sort MyApp->controllers ],
           [ qw/C Controller Model::Dummy::Model/ ],
           'controllers ok');

is_deeply( [ sort MyApp->models ],
           [ qw/Dummy::Model M Model Test::Object/ ],
           'models ok');
