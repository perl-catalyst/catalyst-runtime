package TestApp;

use Catalyst qw[-Engine=Test];

__PACKAGE__->action(
    foo => sub {
        my ( $self, $c ) = @_;
        $c->forward('bar');
    },
    bar => sub {
        my ( $self, $c, $arg ) = @_;
        $c->res->output($arg);
    }
);

package main;

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

ok( get('/foo/bar') =~ /bar/ );
