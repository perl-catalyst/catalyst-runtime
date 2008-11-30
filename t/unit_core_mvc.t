use Test::More tests => 45;
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

    # allow $c->log->warn to work
    __PACKAGE__->setup_log;
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

# failed search
{
    is( MyApp->model('DNE'), undef, 'undef for invalid search' );
}

is_deeply( [ sort MyApp->views ],
           [ qw/V View/ ],
           'views ok' );

is_deeply( [ sort MyApp->controllers ],
           [ qw/C Controller Model::Dummy::Model/ ],
           'controllers ok');

is_deeply( [ sort MyApp->models ],
           [ qw/Dummy::Model M Model Test::Object/ ],
           'models ok');

{
    my $warnings = 0;
    no warnings 'redefine';
    local *Catalyst::Log::warn = sub { $warnings++ };

    like (MyApp->view , qr/^MyApp\::(V|View)\::/ , 'view() with no defaults returns *something*');
    ok( $warnings, 'view() w/o a default is random, warnings thrown' );
}

is ( bless ({stash=>{current_view=>'V'}}, 'MyApp')->view , 'MyApp::View::V', 'current_view ok');

my $view = bless {} , 'MyApp::View::V'; 
is ( bless ({stash=>{current_view_instance=> $view }}, 'MyApp')->view , $view, 'current_view_instance ok');

is ( bless ({stash=>{current_view_instance=> $view, current_view=>'MyApp::V::View' }}, 'MyApp')->view , $view, 
  'current_view_instance precedes current_view ok');

{
    my $warnings = 0;
    no warnings 'redefine';
    local *Catalyst::Log::warn = sub { $warnings++ };

    like (MyApp->model , qr/^MyApp\::(M|Model)\::/ , 'model() with no defaults returns *something*');
    ok( $warnings, 'model() w/o a default is random, warnings thrown' );
}

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

# regexp behavior tests
{
    # is_deeply is used because regexp behavior means list context
    is_deeply( [ MyApp->view( qr{^V[ie]+w$} ) ], [ 'MyApp::V::View' ], 'regexp view ok' );
    is_deeply( [ MyApp->controller( qr{Dummy\::Model$} ) ], [ 'MyApp::Controller::Model::Dummy::Model' ], 'regexp controller ok' );
    is_deeply( [ MyApp->model( qr{Dum{2}y} ) ], [ 'MyApp::Model::Dummy::Model' ], 'regexp model ok' );
    
    # object w/ qr{}
    is_deeply( [ MyApp->model( qr{Test} ) ], [ MyApp->components->{'MyApp::Model::Test::Object'} ], 'Object returned' );

    {
        my $warnings = 0;
        no warnings 'redefine';
        local *Catalyst::Log::warn = sub { $warnings++ };

        # object w/ regexp fallback
        is_deeply( [ MyApp->model( 'Test' ) ], [ MyApp->components->{'MyApp::Model::Test::Object'} ], 'Object returned' );
        ok( $warnings, 'regexp fallback warnings' );
    }

    is_deeply( [ MyApp->view('MyApp::V::View$') ], [ 'MyApp::V::View' ], 'Explicit return ok');
    is_deeply( [ MyApp->controller('MyApp::C::Controller$') ], [ 'MyApp::C::Controller' ], 'Explicit return ok');
    is_deeply( [ MyApp->model('MyApp::M::Model$') ], [ 'MyApp::M::Model' ], 'Explicit return ok');
}

{
    my @expected = qw( MyApp::C::Controller MyApp::Controller::C );
    is_deeply( [ sort MyApp->controller( qr{^C} ) ], \@expected, 'multiple controller returns from regexp search' );
}

{
    my @expected = qw( MyApp::V::View MyApp::View::V );
    is_deeply( [ sort MyApp->view( qr{^V} ) ], \@expected, 'multiple view returns from regexp search' );
}

{
    my @expected = qw( MyApp::M::Model MyApp::Model::M );
    is_deeply( [ sort MyApp->model( qr{^M} ) ], \@expected, 'multiple model returns from regexp search' );
}

# failed search
{
    is( scalar MyApp->controller( qr{DNE} ), 0, '0 results for failed search' );
}

#checking @args passed to ACCEPT_CONTEXT
{
    my $args;

    {
        no warnings 'once';
        *MyApp::Model::M::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
        *MyApp::View::V::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
    }

    my $c = bless {}, 'MyApp';

    # test accept-context with class rather than instance
    MyApp->model('M', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], 'MyApp->model args passed to ACCEPT_CONTEXT ok');


    $c->model('M', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], '$c->model args passed to ACCEPT_CONTEXT ok');

    my $x = $c->view('V', qw/foo2 bar2/);
    is_deeply($args, [qw/foo2 bar2/], '$c->view args passed to ACCEPT_CONTEXT ok');

    # regexp fallback
    $c->view('::View::V', qw/foo3 bar3/);
    is_deeply($args, [qw/foo3 bar3/], 'args passed to ACCEPT_CONTEXT ok');


}
