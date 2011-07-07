use Test::More;
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
    is_deeply( [ MyApp->comp( qr{Model} ) ], [ 'MyApp::M::Model' ], 'regexp ok' );

    {
        my $warnings = 0;
        no warnings 'redefine';
        local *Catalyst::Log::warn = sub { $warnings++ };

        is_deeply( [ MyApp->comp('::M::Model') ], \@complist, 'no results for regexp fallback');
        ok( $warnings, 'regexp fallback warnings' );
    }
}

# multiple returns
{
    my @expected = sort qw( MyApp::C::Controller MyApp::M::Model );
    my @got = sort MyApp->comp( qr{::[MC]::} );
    is_deeply( \@got, \@expected, 'multiple results from regexp ok' );
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
}

done_testing;
