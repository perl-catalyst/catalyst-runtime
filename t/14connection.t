package TestApp;

use Catalyst;

__PACKAGE__->action(
    hostname => sub {
        my ( $self, $c ) = @_;
        $c->res->output( $c->req->hostname );
    },
    address => sub {
        my ( $self, $c ) = @_;
        $c->res->output( $c->req->address );
    }
);

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/hostname') eq 'localhost' );
ok( get('/address')  eq '127.0.0.1' );
