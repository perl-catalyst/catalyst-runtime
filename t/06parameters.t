package TestApp;

use Catalyst qw[-Engine=Test];

__PACKAGE__->action(
    foo => sub {
        my ( $self, $c ) = @_;
        $c->res->output( $c->req->params->{foo} );
    }
);

package main;

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

ok( get('/foo?foo=bar') =~ /bar/ );
