package TestApp;

use Catalyst;

__PACKAGE__->action(
    foo => sub {
        my ( $self, $c ) = @_;
        $c->stash->{test} ||= 'foo';
        $c->forward('bar');
    },
    bar => sub {
        my ( $self, $c ) = @_;
        $c->stash->{test} ||= 'bar';
        $c->forward('yada');
    },
    yada => sub {
        my ( $self, $c ) = @_;
        $c->stash->{test} ||= 'yada';
        $c->res->output( $c->stash->{test} );
    }
);

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo') =~ /foo/ );
ok( get('/bar') =~ /bar/ );
