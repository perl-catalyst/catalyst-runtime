package TestApp;

use Catalyst;

__PACKAGE__->action(

    '!begin' => sub {
        my ( $self, $c ) = @_;
        $c->res->output('foo');
    },

    '!default' => sub { },

    '!end' => sub {
        my ( $self, $c ) = @_;
        $c->res->output( $c->res->output . 'bar' );
    },

);

package TestApp::C::Foo::Bar;

TestApp->action(

    '!?begin' => sub {
        my ( $self, $c ) = @_;
        $c->res->output('yada');
    },

    '!?default' => sub { },

    '!?end' => sub {
        my ( $self, $c ) = @_;
        $c->res->output('yada');
        $c->res->output( $c->res->output . 'yada' );
    },

);

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo')         =~ /foobar/ );
ok( get('/foo_bar/foo') =~ /yadayada/ );
