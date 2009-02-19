use Test::More tests => 22;
use strict;
use warnings;

use_ok('Catalyst');

my @complist = map { "MyApp::$_"; } qw/C::Controller M::Model V::View/;

{
  package MyApp;

  use base qw/Catalyst/;

  __PACKAGE__->components({ map { ($_, $_) } @complist });

  # this is so $c->log->warn will work
  __PACKAGE__->setup_log;
}

is(MyApp->comp('MyApp::V::View'), 'MyApp::V::View', 'Explicit return ok');

is(MyApp->comp('C::Controller'), 'MyApp::C::Controller', 'Two-part return ok');

is(MyApp->comp('Model'), 'MyApp::M::Model', 'Single part return ok');

is_deeply([ MyApp->comp() ], \@complist, 'Empty return ok');

# Is this desired behaviour?
is_deeply([ MyApp->comp('Foo') ], \@complist, 'Fallthrough return ok');

# regexp behavior
{
    is_deeply( [ MyApp->comp( qr{Model} ) ], [ 'MyApp::M::Model'], 'regexp ok' );
    is_deeply( [ MyApp->comp('MyApp::V::View$') ], [ 'MyApp::V::View' ], 'Explicit return ok');
    is_deeply( [ MyApp->comp('MyApp::C::Controller$') ], [ 'MyApp::C::Controller' ], 'Explicit return ok');
    is_deeply( [ MyApp->comp('MyApp::M::Model$') ], [ 'MyApp::M::Model' ], 'Explicit return ok');

    # a couple other varieties for regexp fallback
    is_deeply( [ MyApp->comp('M::Model') ], [ 'MyApp::M::Model' ], 'Explicit return ok');

    {
        my $warnings = 0;
        no warnings 'redefine';
        local *Catalyst::Log::warn = sub { $warnings++ };

        is_deeply( [ MyApp->comp('::M::Model') ], [ 'MyApp::M::Model' ], 'Explicit return ok');
        ok( $warnings, 'regexp fallback warnings' );

        $warnings = 0;
        is_deeply( [ MyApp->comp('Mode') ], [ 'MyApp::M::Model' ], 'Explicit return ok');
        ok( $warnings, 'regexp fallback warnings' );

        $warnings = 0;
        is(MyApp->comp('::M::'), 'MyApp::M::Model', 'Regex return ok');
        ok( $warnings, 'regexp fallback for comp() warns' );
    }

}

# multiple returns
{
    my @expected = qw( MyApp::C::Controller MyApp::M::Model );
    is_deeply( [ MyApp->comp( qr{::[MC]::} ) ], \@expected, 'multiple results fro regexp ok' );
}

# failed search
{
    is_deeply( scalar MyApp->comp( qr{DNE} ), 0, 'no results for failed search' );
}


#checking @args passed to ACCEPT_CONTEXT
{
    my $args;

    {
        no warnings 'once';
        *MyApp::M::Model::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
    }

    my $c = bless {}, 'MyApp';

    $c->component('MyApp::M::Model', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], 'args passed to ACCEPT_CONTEXT ok');

    $c->component('M::Model', qw/foo2 bar2/);
    is_deeply($args, [qw/foo2 bar2/], 'args passed to ACCEPT_CONTEXT ok');

    $c->component('Mode', qw/foo3 bar3/);
    is_deeply($args, [qw/foo3 bar3/], 'args passed to ACCEPT_CONTEXT ok');
} 

