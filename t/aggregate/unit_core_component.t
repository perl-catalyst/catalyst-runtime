use Test::More;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use TestAppComponent;

my @complist = map { "TestAppComponent::$_"; } qw/C::Controller M::Model V::View/;

is(ref TestAppComponent->comp('TestAppComponent::V::View'), 'TestAppComponent::V::View', 'Explicit return ok');

is(ref TestAppComponent->comp('C::Controller'), 'TestAppComponent::C::Controller', 'Two-part return ok');

is(ref TestAppComponent->comp('Model'), 'TestAppComponent::M::Model', 'Single part return ok');

is_deeply([ TestAppComponent->comp() ], \@complist, 'Empty return ok');

# Is this desired behaviour?
is_deeply([ TestAppComponent->comp('Foo') ], \@complist, 'Fallthrough return ok');

# regexp behavior
{
    is_deeply( [ map { ref $_ } TestAppComponent->comp( qr{Model} ) ], [ 'TestAppComponent::M::Model' ], 'regexp ok' );

    {
        my $warnings = 0;
        no warnings 'redefine';
        local *Catalyst::Log::warn = sub { $warnings++ };

        is_deeply( [ TestAppComponent->comp('::M::Model') ], \@complist, 'no reulsts for regexp fallback');
        ok( $warnings, 'regexp fallback warnings' );
    }

}

# multiple returns
{
    # already sorted
    my @expected = qw( TestAppComponent::C::Controller TestAppComponent::M::Model );
    my @got = map { ref $_ } sort TestAppComponent->comp( qr{::[MC]::} );
    is_deeply( \@got, \@expected, 'multiple results from regexp ok' );
}

# failed search
{
    is_deeply( scalar TestAppComponent->comp( qr{DNE} ), 0, 'no results for failed search' );
}


#checking @args passed to ACCEPT_CONTEXT
{
    my $args;

    {
        no warnings 'once';
        *TestAppComponent::M::Model::ACCEPT_CONTEXT = sub { my ($self, $c, @args) = @_; $args= \@args};
    }

    my $c = bless {}, 'TestAppComponent';

    $c->component('TestAppComponent::M::Model', qw/foo bar/);
    is_deeply($args, [qw/foo bar/], 'args passed to ACCEPT_CONTEXT ok');

    $c->component('M::Model', qw/foo2 bar2/);
    is_deeply($args, [qw/foo2 bar2/], 'args passed to ACCEPT_CONTEXT ok');
}

done_testing;
