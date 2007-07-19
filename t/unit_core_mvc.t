use Test::More tests => 27;
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

is (MyApp->view , 'MyApp::V::View', 'view() with no defaults ok');

is ( bless ({stash=>{current_view=>'V'}}, 'MyApp')->view , 'MyApp::View::V', 'current_view ok');

my $view = bless {} , 'MyApp::View::V'; 
is ( bless ({stash=>{current_view_instance=> $view }}, 'MyApp')->view , $view, 'current_view_instance ok');

is ( bless ({stash=>{current_view_instance=> $view, current_view=>'MyApp::V::View' }}, 'MyApp')->view , $view, 
  'current_view_instance precedes current_view ok');

is (MyApp->model , 'MyApp::M::Model', 'model() with no defaults ok');

is ( bless ({stash=>{current_model=>'M'}}, 'MyApp')->model , 'MyApp::Model::M', 'current_model ok');

my $model = bless {} , 'MyApp::Model::M'; 
is ( bless ({stash=>{current_model_instance=> $model }}, 'MyApp')->model , $model, 'current_model_instance ok');

is ( bless ({stash=>{current_model_instance=> $model, current_model=>'MyApp::M::Model' }}, 'MyApp')->model , $model, 
  'current_model_instance precedes current_model ok');

MyApp->config->{default_view} = 'V';
is ( bless ({stash=>{}}, 'MyApp')->view , 'MyApp::View::V', 'default_view ok');
is ( MyApp->view , 'MyApp::View::V', 'default_view in class method ok');

MyApp->config->{default_model} = 'M';
is ( bless ({stash=>{}}, 'MyApp')->model , 'MyApp::Model::M', 'default_model ok');
is ( MyApp->model , 'MyApp::Model::M', 'default_model in class method ok');

#checking @args passed to ACCEPT_CONTEXT
my $args;
{
    no warnings; 
    *MyApp::Model::M::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
    *MyApp::View::V::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
} 
MyApp->model('M', qw/foo bar/);
is_deeply($args, [qw/foo bar/], '$c->model args passed to ACCEPT_CONTEXT ok');
MyApp->view('V', qw/baz moo/);
is_deeply($args, [qw/baz moo/], '$c->view args passed to ACCEPT_CONTEXT ok');
