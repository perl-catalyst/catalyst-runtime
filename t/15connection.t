package TestApp;

use Catalyst qw[-Engine=Test];

sub hostname : Global {
    my ( $self, $c ) = @_;
    $c->res->output( $c->req->hostname );
}
sub address : Global {
    my ( $self, $c ) = @_;
    $c->res->output( $c->req->address );
}

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/hostname') eq 'localhost' );
ok( get('/address')  eq '127.0.0.1' );
