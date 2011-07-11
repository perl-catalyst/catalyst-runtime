use Test::More;
use strict;
use warnings;

use Moose::Meta::Class;

use_ok('Catalyst');

our @complist =
  map { "MyMVCTestApp::$_"; }
  qw/C::Controller M::Model V::View Controller::C Model::M View::V Controller::Model::Dummy::Model Model::Dummy::Model/;

foreach my $comp (@complist) {
    Moose::Meta::Class->create(
        $comp =>
            version => '0.1',
    );
}
our $warnings = 0;
our $loaded   = 0;

Moose::Meta::Class->create('Some::Test::Object');

Moose::Meta::Class->create(
    'MyMVCTestApp::Model::Test::Object' =>
        superclasses => [ 'Catalyst::Model', 'Some::Test::Object' ],
);

{
    package MyMVCTestApp;

    use base qw/Catalyst/;

    sub locate_components {
        return (@::complist, 'MyMVCTestApp::Model::Test::Object');
    }

    no warnings 'redefine';
    *Catalyst::Log::warn = sub { $::warnings++ };
    *Catalyst::Utils::ensure_class_loaded = sub {
        my $class = shift;
        $::loaded++
            if Class::MOP::is_class_loaded($class) && $class =~ /^MyMVCTestApp/
    };

    __PACKAGE__->setup;
}

ok( $warnings, 'Issues deprecated warnings' );
is( $loaded, scalar @complist + 1, 'Loaded all components' );

is( MyMVCTestApp->view('View'), 'MyMVCTestApp::V::View', 'V::View ok' );

is( MyMVCTestApp->controller('Controller'),
    'MyMVCTestApp::C::Controller', 'C::Controller ok' );

is( MyMVCTestApp->model('Model'), 'MyMVCTestApp::M::Model', 'M::Model ok' );

is( MyMVCTestApp->model('Dummy::Model'), 'MyMVCTestApp::Model::Dummy::Model', 'Model::Dummy::Model ok' );

isa_ok( MyMVCTestApp->model('Test::Object'), 'Some::Test::Object', 'Test::Object ok' );

is( MyMVCTestApp->controller('Model::Dummy::Model'), 'MyMVCTestApp::Controller::Model::Dummy::Model', 'Controller::Model::Dummy::Model ok' );

is( MyMVCTestApp->view('V'), 'MyMVCTestApp::View::V', 'View::V ok' );

is( MyMVCTestApp->controller('C'), 'MyMVCTestApp::Controller::C', 'Controller::C ok' );

is( MyMVCTestApp->model('M'), 'MyMVCTestApp::Model::M', 'Model::M ok' );

# failed search
{
    is( MyMVCTestApp->model('DNE'), undef, 'undef for invalid search' );
}

is_deeply( [ sort MyMVCTestApp->views ],
           [ qw/V View/ ],
           'views ok' );

is_deeply( [ sort MyMVCTestApp->controllers ],
           [ qw/C Controller Model::Dummy::Model/ ],
           'controllers ok');

is_deeply( [ sort MyMVCTestApp->models ],
           [ qw/Dummy::Model M Model Test::Object/ ],
           'models ok');

{
    $warnings = 0;

    like (MyMVCTestApp->view , qr/^MyMVCTestApp\::(V|View)\::/ , 'view() with no defaults returns *something*');
    ok( $warnings, 'view() w/o a default is random, warnings thrown' );
}

is ( bless ({stash=>{current_view=>'V'}}, 'MyMVCTestApp')->view , 'MyMVCTestApp::View::V', 'current_view ok');

my $view = bless {} , 'MyMVCTestApp::View::V';
is ( bless ({stash=>{current_view_instance=> $view }}, 'MyMVCTestApp')->view , $view, 'current_view_instance ok');

is ( bless ({stash=>{current_view_instance=> $view, current_view=>'MyMVCTestApp::V::View' }}, 'MyMVCTestApp')->view , $view,
  'current_view_instance precedes current_view ok');

{
    $warnings = 0;

    ok( my $model = MyMVCTestApp->model );

    ok( (($model =~ /^MyMVCTestApp\::(M|Model)\::/) ||
        $model->isa('Some::Test::Object')),
        'model() with no defaults returns *something*' );

    ok( $warnings, 'model() w/o a default is random, warnings thrown' );
}

is ( bless ({stash=>{current_model=>'M'}}, 'MyMVCTestApp')->model , 'MyMVCTestApp::Model::M', 'current_model ok');

my $model = bless {} , 'MyMVCTestApp::Model::M';
is ( bless ({stash=>{current_model_instance=> $model }}, 'MyMVCTestApp')->model , $model, 'current_model_instance ok');

is ( bless ({stash=>{current_model_instance=> $model, current_model=>'MyMVCTestApp::M::Model' }}, 'MyMVCTestApp')->model , $model,
  'current_model_instance precedes current_model ok');

{
    use FindBin '$Bin';
    use lib "$Bin/../lib";

    use Catalyst::Test 'TestAppController';

    is( get('/foo/test_controller'), 'bar', 'controller() with empty args returns current controller' );
}

MyMVCTestApp->config->{default_view} = 'V';
is ( bless ({stash=>{}}, 'MyMVCTestApp')->view , 'MyMVCTestApp::View::V', 'default_view ok');
is ( MyMVCTestApp->view , 'MyMVCTestApp::View::V', 'default_view in class method ok');

MyMVCTestApp->config->{default_model} = 'M';
is ( bless ({stash=>{}}, 'MyMVCTestApp')->model , 'MyMVCTestApp::Model::M', 'default_model ok');
is ( MyMVCTestApp->model , 'MyMVCTestApp::Model::M', 'default_model in class method ok');

# regexp behavior tests
{
    # is_deeply is used because regexp behavior means list context
    is_deeply( [ MyMVCTestApp->view( qr{^V[ie]+w$} ) ], [ 'MyMVCTestApp::V::View' ], 'regexp view ok' );
    is_deeply( [ MyMVCTestApp->controller( qr{Dummy\::Model$} ) ], [ 'MyMVCTestApp::Controller::Model::Dummy::Model' ], 'regexp controller ok' );
    is_deeply( [ MyMVCTestApp->model( qr{Dum{2}y} ) ], [ 'MyMVCTestApp::Model::Dummy::Model' ], 'regexp model ok' );

    # object w/ qr{}
    is_deeply( [ MyMVCTestApp->model( qr{Test} ) ], [ MyMVCTestApp->components->{'MyMVCTestApp::Model::Test::Object'} ], 'Object returned' );

    {
        $warnings = 0;

        # object w/ regexp fallback
        is( MyMVCTestApp->model( 'Test' ), undef, 'no regexp fallback' );
        ok( $warnings, 'regexp fallback warnings' );
    }

    is( MyMVCTestApp->view('MyMVCTestApp::V::View$'), undef, 'no regexp fallback');

    is( MyMVCTestApp->controller('MyMVCTestApp::C::Controller$'), undef, 'no regexp fallback');

    is( MyMVCTestApp->model('MyMVCTestApp::M::Model$'), undef, 'no regexp fallback');
}

{
    my @expected = qw( MyMVCTestApp::C::Controller MyMVCTestApp::Controller::C );
    is_deeply( [ sort MyMVCTestApp->controller( qr{^C} ) ], \@expected, 'multiple controller returns from regexp search' );
}

{
    my @expected = qw( MyMVCTestApp::V::View MyMVCTestApp::View::V );
    is_deeply( [ sort MyMVCTestApp->view( qr{^V} ) ], \@expected, 'multiple view returns from regexp search' );
}

{
    my @expected = qw( MyMVCTestApp::M::Model MyMVCTestApp::Model::M );
    is_deeply( [ sort MyMVCTestApp->model( qr{^M} ) ], \@expected, 'multiple model returns from regexp search' );
}

# failed search
{
    is( scalar MyMVCTestApp->controller( qr{DNE} ), 0, '0 results for failed search' );
}

#checking @args passed to ACCEPT_CONTEXT
{
    my $args;

    {
        no warnings 'once';
        *MyMVCTestApp::Model::M::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
        *MyMVCTestApp::View::V::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
    }

    my $c = bless {}, 'MyMVCTestApp';

    # test accept-context with class rather than instance
    MyMVCTestApp->model('M', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], 'MyMVCTestApp->model args passed to ACCEPT_CONTEXT ok');


    $c->model('M', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], '$c->model args passed to ACCEPT_CONTEXT ok');

    my $x = $c->view('V', qw/foo2 bar2/);
    is_deeply($args, [qw/foo2 bar2/], '$c->view args passed to ACCEPT_CONTEXT ok');

}

{
    package MyApp::WithoutRegexFallback;

    use base qw/Catalyst/;

    __PACKAGE__->config( { disable_component_resolution_regex_fallback => 1 } );

    __PACKAGE__->components( { map { ( ref($_)||$_ , $_ ) }
        qw/MyApp::WithoutRegexFallback::Controller::Another::Foo/ } );

    # allow $c->log->warn to work
    __PACKAGE__->setup_log;
}

{
    # test if non-regex component retrieval still works
    is( MyApp::WithoutRegexFallback->controller('Another::Foo'),
        'MyApp::WithoutRegexFallback::Controller::Another::Foo', 'controller Another::Foo found');
}

{
    my $warnings = 0;
    no warnings 'redefine';
    local *Catalyst::Log::warn = sub { $warnings++ };

    # try to get nonexisting object w/o regexp fallback
    is( MyApp::WithoutRegexFallback->controller('Foo'), undef, 'no controller Foo found');
}

done_testing;
