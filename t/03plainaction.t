package TestApp;

use Catalyst;

__PACKAGE__->action(
    foo => sub {
        my ( $self, $c ) = @_;
        $c->res->output('bar');
    }
);

package main;

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

ok( get('/foo') =~ /bar/ );
