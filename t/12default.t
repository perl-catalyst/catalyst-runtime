package TestApp;

use Catalyst qw[-Engine=Test];

__PACKAGE__->action(
    '!default' => sub {
        my ( $self, $c ) = @_;
        $c->res->output('bar');
    }
);

package TestApp::C::Foo::Bar;

TestApp->action(
    '!?default' => sub {
        my ( $self, $c ) = @_;
        $c->res->output('yada');
    }
);

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo')         =~ /bar/ );
ok( get('/foo_bar/foo') =~ /yada/ );
